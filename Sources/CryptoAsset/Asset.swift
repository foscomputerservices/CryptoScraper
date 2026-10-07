// Asset.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// An asset whatever chain or exchange holds it: the class of its instances, one entry of the equivalence map
///
/// Used where the question is which asset, never how much: grouping a report, choosing an asset to trade, joining
/// an exchange's holding to the same asset on a chain.
///
/// ```swift
/// try registry.asset(of: usdt) == .usdt          // true: Binance's tether and Ethereum's are one asset
/// ```
public struct Asset: Codable, Hashable, Identifiable, Sendable, Stubbable {
    /// The class's key: its home instance's id (§ 2.6)
    public let id: String

    /// - Throws: ``AssetError/malformedIdentity(_:)`` when `id` is not a well-formed instance id, as
    ///   ``AssetInstance/init(validating:)`` reads one
    public init(validating id: String) throws {
        // The key is the home instance's id, so it is well-formed exactly when that instance's id is.
        _ = try AssetInstance(validating: id)
        self.id = id
    }

    /// A named unit of an asset: its name, its exponent above the base unit, and how a reader sees it
    ///
    /// ```swift
    /// let gwei = Asset.Unit(name: "gwei", exponent: 9)
    /// ```
    public struct Unit: Codable, Hashable, Sendable, Stubbable {
        public let name: String
        /// Base units per one of this unit, as a power of ten: the base unit is 0, the whole unit is the home
        /// instance's decimals
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

    /// How a whole or base unit is named at declaration; its exponent is the home instance's decimals or 0 and needs
    /// no saying
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

    // MARK: Codable

    // An asset encodes as its id alone, one JSON string, and decodes through the validating initializer.

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        do {
            try self.init(validating: candidate)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a well-formed asset: \"\(candidate)\" (\(error))"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

// MARK: Stubs

extension Asset {
    /// The reserved-fake asset for a test that does not care which: the class whose home is the stub instance
    public static func stub() -> Self { .stub(home: .stub()) }

    /// A stub whose home is any instance
    public static func stub(home: AssetInstance = .stub()) -> Self {
        do {
            return try Asset(validating: home.id)
        } catch {
            preconditionFailure("Asset.stub(home:) with a malformed identity: \(error)")
        }
    }
}

extension Asset.Unit {
    public static func stub() -> Self { .stub(name: "pebble") }

    public static func stub(name: String = "pebble", exponent: Int = 3,
                            symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(name: name, exponent: exponent, symbol: symbol, fractionDigits: fractionDigits)
    }
}

extension Asset.UnitDescription {
    public static func stub() -> Self { .stub(name: "pebble") }

    public static func stub(name: String = "pebble", symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(name: name, symbol: symbol, fractionDigits: fractionDigits)
    }
}

/// Why an asset, an instance or a declaration could not be made
public enum AssetError: Error, Hashable, Sendable {
    /// The text is not a CAIP-2-shaped chain id and an address, or an `iso4217` code
    case malformedIdentity(String)
    /// An instance's decimals outside 0 through 30
    case decimalsOutOfRange(Int)
    /// A unit's exponent is not between 0 and the home instance's decimals, the unit is not the asset's, or the unit
    /// is finer than the base unit of the instance an amount is counted in
    case unitOutOfRange(Asset.Unit)
    /// A declaration that lists no instance
    case noInstances
}

/// The assets a stream settles in and the assets everyone names, by their home instances
///
/// ```swift
/// let stake = try Amount(whole: 100, of: hyperliquidUSDC)
/// try registry.asset(of: hyperliquidUSDC) == .usdc        // true
/// ```
public extension Asset {
    /// The dollar, by its home instance, the dollar itself
    static let usd: Asset = try! Asset(validating: ISO4217.usd.instance.id)
    /// USD Coin, the generated declaration's class, by its home instance, its contract on Ethereum
    static let usdc: Asset = Assets.usdCoin.asset
    /// Tether, the generated declaration's class, by its home instance, its contract on Ethereum
    static let usdt: Asset = Assets.tether.asset
    /// Bitcoin, by its home instance, Bitcoin's coin
    static let btc: Asset = try! Asset(validating: BIP122.Bitcoin.btc.instance.id)
    /// Ether, by its home instance, Ethereum's coin
    static let eth: Asset = try! Asset(validating: EIP155.Ethereum.eth.instance.id)
}
