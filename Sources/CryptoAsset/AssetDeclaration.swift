// AssetDeclaration.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// What is said about one asset: the names a reader counts it in, the name and symbol the reference gives it, and
/// every instance of it, on a chain or on an exchange, with its decimals and its symbol
///
/// Used wherever a value meets a person, a chain or an exchange: rendering an amount in satoshi, reading Kraken's
/// XBT at ten places, joining Binance's tether to Ethereum's.
///
/// ```swift
/// let btc = try registry.declaration(of: .btc)
/// try registry.instance(of: .btc, on: "exchange:kraken").id      // "exchange:kraken:XBT"
/// try registry.decimals(of: krakenXBT)                           // 10
/// ```
public struct AssetDeclaration: Codable, Hashable, Sendable, Stubbable {
    public let asset: Asset

    // What your TokenInfo already states, under its names

    /// The name the reference gives it: "Bitcoin"
    public let tokenName: String
    /// The symbol a reader sees
    public let symbol: AssetSymbol
    /// The reference's own id for it: "bitcoin"
    public let aggregatorId: String?

    // What a person names

    /// The whole unit: its name, sign and fraction digits; the symbol stands in where none was given
    public let wholeUnit: Asset.Unit
    /// The base unit, where the world names it: satoshi, wei, cent
    public let baseUnit: Asset.Unit?
    /// Units named between the base and the whole: gwei
    public let between: [Asset.Unit]
    /// The unit a reader sees by default
    public let displayUnit: Asset.Unit

    // Your CryptoEquivalencyMap's entry

    /// Every instance of the asset, its home first: on its chains and on the exchanges that hold it
    public let instances: [Instance]

    /// One contract on one chain, or one holding on one exchange, that is this asset
    public struct Instance: Codable, Hashable, Sendable, Stubbable {
        public let instance: AssetInstance
        /// 10 ^ `decimals` of the instance's base units make one whole unit: USDC is 6 on Ethereum, Binance
        /// counts its tether at 8, Kraken its bitcoin at 10; 0 through 30
        public let decimals: Int
        /// What this chain or exchange calls it: "XBT" on Kraken
        public let symbol: AssetSymbol

        /// - Throws: ``AssetError/decimalsOutOfRange(_:)`` outside 0 through 30
        public init(instance: AssetInstance, decimals: Int, symbol: AssetSymbol) throws {
            guard (0...30).contains(decimals) else {
                throw AssetError.decimalsOutOfRange(decimals)
            }
            self.instance = instance
            self.decimals = decimals
            self.symbol = symbol
        }

        // MARK: Codable

        // Decoding goes through the validating initializer, so decimals out of range in a stored row are a
        // DecodingError.

        private enum CodingKeys: String, CodingKey {
            case instance
            case decimals
            case symbol
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let instance = try container.decode(AssetInstance.self, forKey: .instance)
            let decimals = try container.decode(Int.self, forKey: .decimals)
            let symbol = try container.decode(AssetSymbol.self, forKey: .symbol)
            do {
                try self.init(instance: instance, decimals: decimals, symbol: symbol)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: .decimals,
                    in: container,
                    debugDescription: "Not a valid instance declaration: \(error)"
                )
            }
        }
    }

    /// - Throws: ``AssetError/noInstances`` when `instances` is empty, or ``AssetError/unitOutOfRange(_:)`` when the
    ///   exponent of a unit in `between` or of `displayUnit` is not between 0 and the home instance's decimals
    public init(asset: Asset, tokenName: String, symbol: AssetSymbol, aggregatorId: String? = nil,
                wholeUnit: Asset.UnitDescription? = nil, baseUnit: Asset.UnitDescription? = nil,
                between: [Asset.Unit] = [], displayUnit: Asset.Unit? = nil,
                instances: [Instance]) throws {
        guard let home = instances.first else {
            throw AssetError.noInstances
        }
        let decimals = home.decimals

        // The whole unit always exists: named by the symbol when no name was given.
        let whole = Asset.Unit(
            name: wholeUnit?.name ?? symbol.text,
            exponent: decimals,
            symbol: wholeUnit?.symbol,
            fractionDigits: wholeUnit?.fractionDigits
        )
        let base = baseUnit.map {
            Asset.Unit(name: $0.name, exponent: 0, symbol: $0.symbol, fractionDigits: $0.fractionDigits)
        }

        // "Between 0 and the home instance's decimals" is read inclusively, for the units between and the display unit.
        for unit in between + [displayUnit].compactMap(\.self) {
            guard (0...decimals).contains(unit.exponent) else {
                throw AssetError.unitOutOfRange(unit)
            }
        }

        self.asset = asset
        self.tokenName = tokenName
        self.symbol = symbol
        self.aggregatorId = aggregatorId
        self.wholeUnit = whole
        self.baseUnit = base
        self.between = between
        self.displayUnit = displayUnit ?? whole
        self.instances = instances
    }

    /// Every unit a reader may count in, at the home instance's decimals
    public var units: [Asset.Unit] {
        [baseUnit].compactMap(\.self) + between + [wholeUnit]
    }

    /// The unit named `name`, or `nil`
    public func unit(named name: String) -> Asset.Unit? {
        units.first { $0.name == name }
    }

    // MARK: Codable

    // Encoding is synthesized. Decoding goes through the validating initializer, so a stored declaration is checked
    // at the boundary as a declared one is.

    private enum CodingKeys: String, CodingKey {
        case asset
        case tokenName
        case symbol
        case aggregatorId
        case wholeUnit
        case baseUnit
        case between
        case displayUnit
        case instances
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let asset = try container.decode(Asset.self, forKey: .asset)
        let tokenName = try container.decode(String.self, forKey: .tokenName)
        let symbol = try container.decode(AssetSymbol.self, forKey: .symbol)
        let aggregatorId = try container.decodeIfPresent(String.self, forKey: .aggregatorId)
        let wholeUnit = try container.decode(Asset.Unit.self, forKey: .wholeUnit)
        let baseUnit = try container.decodeIfPresent(Asset.Unit.self, forKey: .baseUnit)
        let between = try container.decode([Asset.Unit].self, forKey: .between)
        let displayUnit = try container.decode(Asset.Unit.self, forKey: .displayUnit)
        let instances = try container.decode([Instance].self, forKey: .instances)
        do {
            try self.init(
                asset: asset,
                tokenName: tokenName,
                symbol: symbol,
                aggregatorId: aggregatorId,
                wholeUnit: Asset.UnitDescription(name: wholeUnit.name, symbol: wholeUnit.symbol,
                                                 fractionDigits: wholeUnit.fractionDigits),
                baseUnit: baseUnit.map {
                    Asset.UnitDescription(name: $0.name, symbol: $0.symbol, fractionDigits: $0.fractionDigits)
                },
                between: between,
                displayUnit: displayUnit,
                instances: instances
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .instances,
                in: container,
                debugDescription: "Not a valid asset declaration: \(error)"
            )
        }
    }
}

// MARK: Stubs

extension AssetDeclaration {
    public static func stub() -> Self { .stub(tokenName: "Fred") }

    /// A declaration of the stub asset, its one instance the stub instance at 4, an exponent no shipped asset uses
    public static func stub(
        asset: Asset = .stub(),
        tokenName: String = "Fred",
        symbol: AssetSymbol = .stub(),
        aggregatorId: String? = nil,
        wholeUnit: Asset.UnitDescription? = .stub(name: "boulder"),
        baseUnit: Asset.UnitDescription? = .stub(name: "pebble"),
        between: [Asset.Unit] = [],
        displayUnit: Asset.Unit? = nil,
        instances: [Instance] = [.stub()]
    ) -> Self {
        do {
            return try .init(
                asset: asset, tokenName: tokenName, symbol: symbol, aggregatorId: aggregatorId,
                wholeUnit: wholeUnit, baseUnit: baseUnit, between: between, displayUnit: displayUnit,
                instances: instances
            )
        } catch {
            preconditionFailure("AssetDeclaration.stub(…) with an override that is not a valid declaration: \(error)")
        }
    }
}

extension AssetDeclaration.Instance {
    public static func stub() -> Self { .stub(decimals: 4) }

    public static func stub(instance: AssetInstance = .stub(), decimals: Int = 4, symbol: AssetSymbol = .stub()) -> Self {
        do {
            return try .init(instance: instance, decimals: decimals, symbol: symbol)
        } catch {
            preconditionFailure("AssetDeclaration.Instance.stub(…) with an override that is not valid: \(error)")
        }
    }
}
