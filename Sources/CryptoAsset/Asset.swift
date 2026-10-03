// Asset.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// What a quantity is counted in: an asset, a stablecoin or a fiat, with how many base units make a whole unit
///
/// Every asset has a whole unit, named by its symbol unless it carries a name of its own, and a base unit, named
/// where a name exists. Two assets are the same asset when their symbol and exponent are the same; the units are a
/// description and never part of the identity.
///
/// ```swift
/// let usdc = try Asset(symbol: "USDC", unitExponent: 6)          // whole unit "USDC"; the base unit has no name
/// let btc  = try Asset(symbol: "BTC",  unitExponent: 8,
///                      wholeUnit: .init(name: "bitcoin", symbol: "₿", fractionDigits: 8),
///                      baseUnit:  .init(name: "satoshi"))
/// let usd  = try Asset(symbol: "USD",  unitExponent: 2,
///                      wholeUnit: .init(name: "dollar", symbol: "$", fractionDigits: 2),
///                      baseUnit:  .init(name: "cent", symbol: "¢"))
/// let eth  = try Asset(symbol: "ETH",  unitExponent: 18,
///                      wholeUnit: .init(name: "ether", symbol: "Ξ"),
///                      baseUnit:  .init(name: "wei"),
///                      between:   [.init(name: "gwei", exponent: 9)])
/// ```
public struct Asset: Codable, Hashable, Sendable, Stubbable {
    public let symbol: AssetSymbol

    /// The power of ten relating base units to whole units: 10 ^ `unitExponent` base units make one whole unit; 0 through 30
    public let unitExponent: Int

    /// The whole unit: its name, sign and fraction digits; the symbol stands in where none was given
    public let wholeUnit: Unit

    /// The base unit, where it has a name; `nil` for an asset whose smallest unit nobody names
    public let baseUnit: Unit?

    /// Units named between the base and the whole, each at its exponent above the base
    public let between: [Unit]

    /// The unit a reader sees by default: the whole unit unless the asset says otherwise
    public let displayUnit: Unit

    /// - Throws: ``AssetError/unitExponentOutOfRange`` outside 0 through 30, or ``AssetError/unitOutOfRange``
    ///   when a unit's exponent is not between 0 and the asset's
    public init(symbol: AssetSymbol, unitExponent: Int,
                wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
                between: [Unit] = [], displayUnit: Unit? = nil) throws {
        guard (0...30).contains(unitExponent) else {
            throw AssetError.unitExponentOutOfRange(unitExponent)
        }

        // The whole unit always exists: named by the symbol when no name was given.
        let whole = Unit(
            name: wholeUnit?.name ?? symbol.text,
            exponent: unitExponent,
            symbol: wholeUnit?.symbol,
            fractionDigits: wholeUnit?.fractionDigits
        )
        let base = baseUnit.map {
            Unit(name: $0.name, exponent: 0, symbol: $0.symbol, fractionDigits: $0.fractionDigits)
        }

        // "Between 0 and the asset's" is read inclusively, for the units between and for the display unit.
        for unit in between + [displayUnit].compactMap(\.self) {
            guard (0...unitExponent).contains(unit.exponent) else {
                throw AssetError.unitOutOfRange(unit)
            }
        }

        self.symbol = symbol
        self.unitExponent = unitExponent
        self.wholeUnit = whole
        self.baseUnit = base
        self.between = between
        self.displayUnit = displayUnit ?? whole
    }

    /// Validates the symbol too, so a declaration reads as a declaration
    public init(symbol: String, unitExponent: Int,
                wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
                between: [Unit] = [], displayUnit: Unit? = nil) throws {
        try self.init(
            symbol: AssetSymbol(validating: symbol),
            unitExponent: unitExponent,
            wholeUnit: wholeUnit,
            baseUnit: baseUnit,
            between: between,
            displayUnit: displayUnit
        )
    }

    /// A named unit of an asset: its name, its exponent above the base unit, and how a reader sees it
    ///
    /// ```swift
    /// let gwei = Asset.Unit(name: "gwei", exponent: 9)
    /// eth.wholeUnit.exponent          // 18
    /// eth.baseUnit?.name              // "wei"
    /// ```
    public struct Unit: Codable, Hashable, Sendable, Stubbable {
        public let name: String
        /// Base units per one of this unit, as a power of ten: the base unit is 0, the whole unit is the asset's exponent
        public let exponent: Int
        /// A sign a reader sees beside a number in this unit, "$" or "¢" or "₿", or `nil` for the asset's symbol
        public let symbol: String?
        /// How many fraction digits a reader sees by default in this unit, or `nil` for all of them
        public let fractionDigits: Int?
        public init(name: String, exponent: Int, symbol: String? = nil, fractionDigits: Int? = nil) {
            self.name = name
            self.exponent = exponent
            self.symbol = symbol
            self.fractionDigits = fractionDigits
        }
    }

    /// How a whole or base unit is named at declaration; its exponent is the asset's and needs no saying
    public struct UnitDescription: Codable, Hashable, Sendable, Stubbable {
        public let name: String
        public let symbol: String?
        public let fractionDigits: Int?
        public init(name: String, symbol: String? = nil, fractionDigits: Int? = nil) {
            self.name = name
            self.symbol = symbol
            self.fractionDigits = fractionDigits
        }
    }

    /// Every unit a reader may count in: the base unit if named, those between, and the whole unit
    public var units: [Unit] {
        [baseUnit].compactMap(\.self) + between + [wholeUnit]
    }

    /// The unit named `name`, or `nil`
    public func unit(named name: String) -> Unit? {
        units.first { $0.name == name }
    }

    // MARK: Identity

    // Identity is the symbol and the exponent and never the units, so an asset decoded from an exchange with no
    // names and the same asset from the manifest with names are one asset and their amounts add.

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.symbol == rhs.symbol && lhs.unitExponent == rhs.unitExponent
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
        hasher.combine(unitExponent)
    }

    // MARK: Codable

    // Encoding is synthesized: the symbol, the exponent and every unit. Decoding goes through the validating
    // initializer, so a stored asset is checked at the boundary as a declared one is; an exponent or a unit out of
    // range is a DecodingError.

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let symbol = try container.decode(AssetSymbol.self, forKey: .symbol)
        let unitExponent = try container.decode(Int.self, forKey: .unitExponent)
        let wholeUnit = try container.decode(Unit.self, forKey: .wholeUnit)
        let baseUnit = try container.decodeIfPresent(Unit.self, forKey: .baseUnit)
        let between = try container.decode([Unit].self, forKey: .between)
        let displayUnit = try container.decode(Unit.self, forKey: .displayUnit)

        do {
            try self.init(
                symbol: symbol,
                unitExponent: unitExponent,
                wholeUnit: UnitDescription(wholeUnit),
                baseUnit: baseUnit.map(UnitDescription.init),
                between: between,
                displayUnit: displayUnit
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .unitExponent,
                in: container,
                debugDescription: "Not a valid asset: \(error)"
            )
        }
    }
}

private extension Asset.UnitDescription {
    init(_ unit: Asset.Unit) {
        self.init(name: unit.name, symbol: unit.symbol, fractionDigits: unit.fractionDigits)
    }
}

/// Why an asset could not be made
public enum AssetError: Error, Hashable, Sendable {
    case unitExponentOutOfRange(Int)
    case unitOutOfRange(Asset.Unit)
}

public extension Asset {
    /// The assets a stream settles in and the assets everyone names, declared once with their units
    ///
    /// ```swift
    /// let stake = Amount(whole: 100, of: .usdc)
    /// ```
    static let usd: Asset = .declared(
        "USD", unitExponent: 2,
        wholeUnit: .init(name: "dollar", symbol: "$", fractionDigits: 2),
        baseUnit: .init(name: "cent", symbol: "¢")
    )
    static let usdc: Asset = .declared("USDC", unitExponent: 6)
    static let usdt: Asset = .declared("USDT", unitExponent: 6)
    static let btc: Asset = .declared(
        "BTC", unitExponent: 8,
        wholeUnit: .init(name: "bitcoin", symbol: "₿", fractionDigits: 8),
        baseUnit: .init(name: "satoshi")
    )
    static let eth: Asset = .declared(
        "ETH", unitExponent: 18,
        wholeUnit: .init(name: "ether", symbol: "Ξ"),
        baseUnit: .init(name: "wei"),
        between: [.init(name: "gwei", exponent: 9)]
    )
}

extension Asset {
    // A declaration this library makes of its own constants and stubs: valid by construction, so a failure is a
    // programmer error in this file and traps.
    static func declared(_ symbol: String, unitExponent: Int,
                         wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
                         between: [Unit] = [], displayUnit: Unit? = nil) -> Asset {
        do {
            return try Asset(
                symbol: symbol,
                unitExponent: unitExponent,
                wholeUnit: wholeUnit,
                baseUnit: baseUnit,
                between: between,
                displayUnit: displayUnit
            )
        } catch {
            preconditionFailure("Asset \(symbol) is not a valid declaration: \(error)")
        }
    }
}
