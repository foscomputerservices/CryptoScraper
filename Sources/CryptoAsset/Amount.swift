// Amount.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The encoded shape is the contract, on purpose (R5; design § 3.5): a persisted column holds the value and must
// decode by `JSONDecoder` from Postgres JSONB and from SQLite text, with no registry. Stable within a major:
//
//     { "instance": <the instance's id, one JSON string>, "baseUnits": <a bare JSON number, the Int128 at full width> }
//
// The quantity is never a quoted string; a quoted digit string is refused at decode. Pinned at Int128.max and
// Int128.min by the forward-compatibility test in CryptoAssetTests. The instance's decimals are not written: they
// are the statement's, and a declared instance's decimals never change (design § 2.1).
//
// The instance is written before the base units. sqlite-kit (4.5.2) binds a Codable value by first trying its own
// unwrapping encoder and falls back to JSON text only when that encoder throws its SQLCodingError; that encoder does
// not implement Int128, so an Int128 written first throws the standard library's EncodingError instead and the value
// cannot be stored. The two-driver test pins that the order stores.

/// An exact quantity counted in one instance's base units: a holding on an exchange, a contract on a chain
///
/// Carries its instance and its count, nothing else; its decimals are the statement's. Two amounts add only within
/// one instance. Across instances, a conversion goes through the equivalence map, exactly or not at all.
///
/// ```swift
/// let stake = try Amount(whole: 100, of: hyperliquidUSDC)                      // at the holding's 6
/// let fee   = Amount(baseUnits: 2_500, of: hyperliquidUSDC)                     // 0.0025 USDC
/// let after = stake - fee                                                      // exact, no lookup
/// let onChain = try binanceDust.converted(to: ethereumUSDT)                     // 8 to 6: refuses lost digits
/// ```
///
/// Two values that have just arrived from different sources are combined with the throwing pair, which refuses two
/// instances; inside a cycle the operators assume one instance and trap on two.
public struct Amount: Codable, Hashable, Comparable, Sendable, Stubbable {
    /// The count of the instance's base units
    public let baseUnits: Int128
    /// The one instance the count is in
    public let instance: AssetInstance

    /// Pure: how a client's decode and a stored row make an amount; no lookup
    public init(baseUnits: Int128, of instance: AssetInstance) {
        self.baseUnits = baseUnits
        self.instance = instance
    }

    /// A whole number of whole units, at the instance's decimals
    ///
    /// - Precondition: `whole` times 10 ^ the instance's decimals fits an `Int128`
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)``
    public init(whole: Int, of instance: AssetInstance, in registry: AssetRegistry = .shared) throws {
        let decimals = try registry.decimals(of: instance)
        self.init(baseUnits: Int128(whole).timesExactly(.powerOfTen(decimals)), of: instance)
    }

    /// A count of a named unit of the instance's asset, exactly
    ///
    /// The units are the declaration's, at the home instance's decimals; on another instance a unit counts at its
    /// place relative to that instance's own base unit.
    ///
    /// - Precondition: the count in the instance's base units fits an `Int128`
    /// - Throws: ``AssetError/unitOutOfRange(_:)`` when `unit` is not the asset's, or is finer than the instance's base
    ///   unit; ``AssetRegistryError/undeclaredInstance(_:)``
    public init(count: Int128, in unit: Asset.Unit, of instance: AssetInstance,
                in registry: AssetRegistry = .shared) throws {
        let exponent = try Self.exponent(of: unit, on: instance, in: registry)
        self.init(baseUnits: count.timesExactly(.powerOfTen(exponent)), of: instance)
    }

    /// The quantity read in a named unit, exactly: the whole count of that unit, toward zero, and the base units left
    /// over, which carry the quantity's sign
    ///
    /// - Throws: ``AssetError/unitOutOfRange(_:)`` when `unit` is not the asset's, or is finer than the instance's base
    ///   unit; ``AssetRegistryError/undeclaredInstance(_:)``
    public func count(in unit: Asset.Unit, in registry: AssetRegistry = .shared) throws -> (count: Int128, remainder: Int128) {
        let exponent = try Self.exponent(of: unit, on: instance, in: registry)
        let (count, remainder) = baseUnits.quotientAndRemainder(dividingBy: .powerOfTen(exponent))
        return (count: count, remainder: remainder)
    }

    /// The same quantity in another instance of the same asset, exactly: up is exact where it fits, down refuses lost
    /// digits
    ///
    /// - Throws: ``AmountError/notEquivalent(_:_:)`` when the map does not put both in one asset;
    ///   ``AmountError/notRepresentable(_:in:)`` when `instance` cannot hold it;
    ///   ``AssetRegistryError/undeclaredInstance(_:)`` when either is undeclared
    public func converted(to instance: AssetInstance, in registry: AssetRegistry = .shared) throws -> Amount {
        guard try registry.isEquivalent(self.instance, instance) else {
            throw AmountError.notEquivalent(self.instance, instance)
        }
        let from = try registry.decimals(of: self.instance)
        let to = try registry.decimals(of: instance)
        if to >= from {
            // Up is exact while it fits.
            let (converted, overflow) = baseUnits.multipliedReportingOverflow(by: .powerOfTen(to - from))
            guard !overflow else {
                throw AmountError.notRepresentable(self, in: instance)
            }
            return Amount(baseUnits: converted, of: instance)
        }
        // Down refuses lost digits.
        let (converted, remainder) = baseUnits.quotientAndRemainder(dividingBy: .powerOfTen(from - to))
        guard remainder == 0 else {
            throw AmountError.notRepresentable(self, in: instance)
        }
        return Amount(baseUnits: converted, of: instance)
    }

    /// Total: two amounts of different instances are not equal and do not trap
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.instance == rhs.instance && lhs.baseUnits == rhs.baseUnits
    }

    /// - Precondition: both amounts are of one instance
    public static func < (lhs: Self, rhs: Self) -> Bool {
        requireOneInstance(lhs.instance, rhs.instance, "Amount <")
        return lhs.baseUnits < rhs.baseUnits
    }

    /// - Precondition: both amounts are of one instance
    public static func + (lhs: Self, rhs: Self) -> Self {
        requireOneInstance(lhs.instance, rhs.instance, "Amount +")
        return Self(baseUnits: lhs.baseUnits + rhs.baseUnits, of: lhs.instance)
    }

    /// - Precondition: both amounts are of one instance
    public static func - (lhs: Self, rhs: Self) -> Self {
        requireOneInstance(lhs.instance, rhs.instance, "Amount -")
        return Self(baseUnits: lhs.baseUnits - rhs.baseUnits, of: lhs.instance)
    }

    public static prefix func - (operand: Self) -> Self {
        Self(baseUnits: -operand.baseUnits, of: operand.instance)
    }

    /// Scales exactly and rounds toward zero, discarding what is below one base unit
    ///
    /// ```swift
    /// let half = stake * Fraction(percent: 50)
    /// let margin = notional / Fraction(integer: 2)
    /// ```
    ///
    public static func * (lhs: Self, rhs: Fraction) -> Self {
        Self(baseUnits: lhs.baseUnits.scaled(by: rhs.scaledNumerator, over: .assetScale), of: lhs.instance)
    }

    /// Divides exactly and rounds toward zero, discarding what is below one base unit
    ///
    /// - Precondition: `rhs` is not zero
    public static func / (lhs: Self, rhs: Fraction) -> Self {
        precondition(!rhs.isZero, "Amount / Fraction.zero")
        return Self(baseUnits: lhs.baseUnits.scaled(by: .assetScale, over: rhs.scaledNumerator), of: lhs.instance)
    }

    public static func zero(of instance: AssetInstance) -> Self {
        Self(baseUnits: 0, of: instance)
    }

    public var isZero: Bool {
        baseUnits == 0
    }

    public var isNegative: Bool {
        baseUnits < 0
    }

    /// - Throws: ``AmountError/instanceConflict(_:_:)`` when the instances differ
    public func adding(_ other: Self) throws -> Self {
        guard instance == other.instance else {
            throw AmountError.instanceConflict(instance, other.instance)
        }
        return self + other
    }

    /// - Throws: ``AmountError/instanceConflict(_:_:)`` when the instances differ
    public func subtracting(_ other: Self) throws -> Self {
        guard instance == other.instance else {
            throw AmountError.instanceConflict(instance, other.instance)
        }
        return self - other
    }

    // MARK: Codable

    private enum CodingKeys: CodingKey {
        case instance
        case baseUnits
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.instance = try container.decode(AssetInstance.self, forKey: .instance)
        self.baseUnits = try container.decode(Int128.self, forKey: .baseUnits)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instance, forKey: .instance)
        try container.encode(baseUnits, forKey: .baseUnits)
    }
}

// MARK: Stubs

extension Amount {
    public static func stub() -> Self { .stub(baseUnits: 42) }

    public static func stub(baseUnits: Int128 = 42, of instance: AssetInstance = .stub()) -> Self {
        .init(baseUnits: baseUnits, of: instance)
    }
}

private extension Amount {
    // The power of ten of `instance`'s base units in one `unit`: the unit's exponent is at the home instance's
    // decimals, so it moves by the difference between the two instances' decimals.
    static func exponent(of unit: Asset.Unit, on instance: AssetInstance, in registry: AssetRegistry) throws -> Int {
        let declaration = try registry.declaration(of: registry.asset(of: instance))
        guard declaration.units.contains(unit) else {
            throw AssetError.unitOutOfRange(unit)
        }
        let home = declaration.instances[0].decimals
        let exponent = unit.exponent + (try registry.decimals(of: instance)) - home
        guard exponent >= 0 else {
            throw AssetError.unitOutOfRange(unit)
        }
        return exponent
    }
}
