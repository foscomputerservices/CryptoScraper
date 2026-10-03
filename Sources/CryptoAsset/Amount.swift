// Amount.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The encoded shape is the contract, on purpose (R5; § 9.7 of the protocols): a persisted column holds the value
// and must decode by `JSONDecoder` from Postgres JSONB and from SQLite text. Stable within a major:
//
//     { "baseUnits": <a bare JSON number, the Int128 at full width>, "asset": <the Asset, with its units> }
//
// The quantity is never a quoted string; a quoted digit string is refused at decode. Pinned at Int128.max and
// Int128.min by the forward-compatibility test in CryptoAssetTests.
//
// The asset is written before the base units. A JSON object's order carries no meaning, but sqlite-kit (4.5.2)
// binds a Codable value by first trying its own unwrapping encoder and falls back to JSON text only when that
// encoder throws its SQLCodingError; that encoder does not implement Int128, so an Int128 written first throws the
// standard library's EncodingError instead and the value cannot be stored. Written first, the asset meets the
// unwrapping encoder's keyed refusal and the fallback stores the whole value as JSON text.

/// An exact quantity of one asset, counted in that asset's base units
///
/// Every amount, size and balance is one of these. Arithmetic is on the integer and is exact; nothing here rounds
/// for a reader. A view receives the amount and localizes it.
///
/// ```swift
/// let stake = Amount(whole: 100, of: usdc)                  // 100 USDC, exactly
/// let fee   = Amount(baseUnits: 2_500, asset: usdc)         // 0.0025 USDC, as the exchange counted it
/// let after = stake - fee                                   // exact
/// ```
///
/// A named unit converts exactly, both ways, as a count and never as text:
///
/// ```swift
/// let tip  = try Amount(count: 5, in: gwei, of: eth)         // 5 gwei, exactly
/// tip.count(in: gwei)                                        // (count: 5, remainder: 0)
/// ```
///
/// What an exchange sends as text arrives as an `Amount` already: the client's response model decodes it.
///
/// Two values that have just arrived from different sources are combined with the throwing pair, which refuses
/// two assets; inside a cycle the operators assume one asset and trap on two:
///
/// ```swift
/// let total = try ledgerBalance.adding(exchangeBalance)
/// ```
///
/// Encodes as its base units and its asset, so a stored value says what its own balance is.
public struct Amount: Codable, Hashable, Comparable, Sendable, Stubbable {
    /// The count of base units
    public let baseUnits: Int128
    public let asset: Asset

    public init(baseUnits: Int128, asset: Asset) {
        self.baseUnits = baseUnits
        self.asset = asset
    }

    /// A whole number of whole units, exactly
    public init(whole: Int, of asset: Asset) {
        self.init(baseUnits: Int128(whole).timesExactly(.powerOfTen(asset.unitExponent)), asset: asset)
    }

    /// A count of a named unit, exactly
    ///
    /// - Throws: ``AssetError/unitOutOfRange`` when `unit` is not the asset's
    public init(count: Int128, in unit: Asset.Unit, of asset: Asset) throws {
        guard asset.units.contains(unit) else {
            throw AssetError.unitOutOfRange(unit)
        }
        self.init(baseUnits: count.timesExactly(.powerOfTen(unit.exponent)), asset: asset)
    }

    /// The quantity read in a named unit, exactly: the whole count of that unit and the base units left over
    ///
    /// - Precondition: `unit` is one of the asset's units
    public func count(in unit: Asset.Unit) -> (count: Int128, remainder: Int128) {
        precondition(asset.units.contains(unit), "\(unit.name) is not a unit of \(asset.symbol.text)")
        let (count, remainder) = baseUnits.quotientAndRemainder(dividingBy: .powerOfTen(unit.exponent))
        return (count: count, remainder: remainder)
    }

    /// `==` is total: two amounts of different assets are not equal and do not trap
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.asset == rhs.asset && lhs.baseUnits == rhs.baseUnits
    }

    /// - Precondition: both amounts are of one asset
    public static func < (lhs: Self, rhs: Self) -> Bool {
        requireOneAsset(lhs.asset, rhs.asset, "Amount <")
        return lhs.baseUnits < rhs.baseUnits
    }

    /// - Precondition: both amounts are of one asset
    public static func + (lhs: Self, rhs: Self) -> Self {
        requireOneAsset(lhs.asset, rhs.asset, "Amount +")
        return Self(baseUnits: lhs.baseUnits + rhs.baseUnits, asset: lhs.asset)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        requireOneAsset(lhs.asset, rhs.asset, "Amount -")
        return Self(baseUnits: lhs.baseUnits - rhs.baseUnits, asset: lhs.asset)
    }

    public static prefix func - (operand: Self) -> Self {
        Self(baseUnits: -operand.baseUnits, asset: operand.asset)
    }

    /// Scales exactly and rounds toward zero, discarding what is below one base unit
    ///
    /// ```swift
    /// let half = stake * Fraction(percent: 50)
    /// let margin = notional / Fraction(integer: 2)
    /// ```
    ///
    /// - Precondition: for `/`, `rhs` is not zero
    public static func * (lhs: Self, rhs: Fraction) -> Self {
        Self(baseUnits: lhs.baseUnits.scaled(by: rhs.scaledNumerator, over: .assetScale), asset: lhs.asset)
    }

    public static func / (lhs: Self, rhs: Fraction) -> Self {
        precondition(!rhs.isZero, "Amount / Fraction.zero")
        return Self(baseUnits: lhs.baseUnits.scaled(by: .assetScale, over: rhs.scaledNumerator), asset: lhs.asset)
    }

    public static func zero(of asset: Asset) -> Self {
        Self(baseUnits: 0, asset: asset)
    }

    public var isZero: Bool {
        baseUnits == 0
    }

    public var isNegative: Bool {
        baseUnits < 0
    }

    /// - Throws: ``AmountError/assetConflict`` when the assets differ
    public func adding(_ other: Self) throws -> Self {
        guard asset == other.asset else {
            throw AmountError.assetConflict(asset.symbol, other.asset.symbol)
        }
        return self + other
    }

    public func subtracting(_ other: Self) throws -> Self {
        guard asset == other.asset else {
            throw AmountError.assetConflict(asset.symbol, other.asset.symbol)
        }
        return self - other
    }

    // MARK: Codable

    private enum CodingKeys: CodingKey {
        case baseUnits
        case asset
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.asset = try container.decode(Asset.self, forKey: .asset)
        self.baseUnits = try container.decode(Int128.self, forKey: .baseUnits)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(asset, forKey: .asset)
        try container.encode(baseUnits, forKey: .baseUnits)
    }
}
