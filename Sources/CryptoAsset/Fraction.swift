// Fraction.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// Sealed: the numerator at scale 10^9 (`Int128.assetScale`) is the representation and is nobody's business, so no
// property vends it and no initializer takes it (§ 9.7 of the protocols). `scaledNumerator` is internal so Amount
// and Price can scale by it. The encoded shape is deliberately undocumented; it is pinned by the round-trip test
// alone.
//
// The encoding states its scale beside the numerator, the scale first, and decoding refuses any other scale. The
// scale written first is also what lets sqlite-kit (4.5.2) store a Fraction: its unwrapping encoder does not
// implement Int128, so a value whose first entry is an Int128 throws the standard library's EncodingError instead
// of the SQLCodingError on which sqlite-kit falls back to JSON text.

/// An exact ratio: a gain in percent of the amount in, a share of months, a slippage step, a stop distance, a leverage
///
/// A fraction is an integer numerator at a fixed scale, so it is exact to nine fraction digits and no further.
/// From basis points, from a percent and from an integer it is exact; from two amounts it is a division and rounds
/// toward zero at the scale.
///
/// ```swift
/// let gain     = Fraction(amountOut - amountIn, over: amountIn)   // the gain, as a fraction of the amount in
/// let step     = Fraction(basisPoints: 25)                     // 0.25 %, a slippage step
/// let distance = Fraction(percent: 2)                          // a stop distance
/// let leverage = Fraction(integer: 2)                          // 2x
/// let level    = entry * (.one - distance)                     // a long's stop level
/// ```
public struct Fraction: Codable, Hashable, Comparable, Sendable, Stubbable {
    // The ratio times 10^9.
    let scaledNumerator: Int128

    private init(scaledNumerator: Int128) {
        self.scaledNumerator = scaledNumerator
    }

    public static let zero: Fraction = .init(scaledNumerator: 0)
    public static let one: Fraction = .init(scaledNumerator: .assetScale)

    public init(basisPoints: Int) {
        self.init(scaledNumerator: Int128(basisPoints) * 100_000)
    }

    public init(percent: Int) {
        self.init(scaledNumerator: Int128(percent) * 10_000_000)
    }

    public init(integer: Int) {
        self.init(scaledNumerator: Int128(integer) * .assetScale)
    }

    /// - Precondition: both amounts are of one instance; `whole` is not zero
    public init(_ part: Amount, over whole: Amount) {
        requireOneInstance(part.instance, whole.instance, "Fraction(_:over:)")
        precondition(!whole.isZero, "Fraction(_:over:) with a zero whole")
        self.init(scaledNumerator: part.baseUnits.scaled(by: .assetScale, over: whole.baseUnits))
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(scaledNumerator: lhs.scaledNumerator + rhs.scaledNumerator)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(scaledNumerator: lhs.scaledNumerator - rhs.scaledNumerator)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.scaledNumerator < rhs.scaledNumerator
    }

    public var isZero: Bool {
        scaledNumerator == 0
    }

    public var isNegative: Bool {
        scaledNumerator < 0
    }

    // Price.spread(to:) builds its result at the scale directly.
    static func atScale(_ scaledNumerator: Int128) -> Self {
        Self(scaledNumerator: scaledNumerator)
    }

    // MARK: Codable

    // The power of ten of the scale, as written beside the numerator.
    private static let scaleExponent = 9

    private enum CodingKeys: CodingKey {
        case scaleExponent
        case numerator
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scaleExponent = try container.decode(Int.self, forKey: .scaleExponent)
        guard scaleExponent == Self.scaleExponent else {
            throw DecodingError.dataCorruptedError(
                forKey: .scaleExponent,
                in: container,
                debugDescription: "A fraction at scale 10^\(scaleExponent); this library reads 10^\(Self.scaleExponent)"
            )
        }
        self.scaledNumerator = try container.decode(Int128.self, forKey: .numerator)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.scaleExponent, forKey: .scaleExponent)
        try container.encode(scaledNumerator, forKey: .numerator)
    }
}

// MARK: Stubs

extension Fraction {
    public static func stub() -> Self { .stub(percent: 42) }

    // A fraction's numerator is sealed, so its stub takes the percent it is made from.
    public static func stub(percent: Int = 42) -> Self {
        .init(percent: percent)
    }
}
