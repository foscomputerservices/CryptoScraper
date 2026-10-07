// Price.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// A price carries no decimals (design § 3.4, the owner's road B of 2026-10-07): the value is its two instances and
// `scaled`, and that is the whole of the stored row, `{ "quote": …, "base": …, "scaled": … }`, decoded with no
// registry. The base's decimals are read from the statement when the price meets an amount: at `init(_:per:)` over
// a size, and at `cost(of:)`. The initializer that takes `scaled` is the decoder's and is not public.

/// An amount of a quote instance per one whole unit of a base instance: 65,000 USD per BTC
///
/// A price names two instances: Kraken's price is `exchange:kraken:USD` per `exchange:kraken:XBT`. The cost it
/// produces is in the quote instance; the size it is applied to is in the base instance. It is held at a scale, so
/// a price below one quote base unit per whole base unit is exact to nine fraction digits of a quote base unit.
///
/// ```swift
/// let mid  = try Price(try Amount(whole: 65_000, of: krakenUSD), per: krakenXBT)
/// let cost = try mid.cost(of: size)                                // in krakenUSD, at the base's decimals
/// let ask  = mid * (.one + Fraction(basisPoints: 5))               // one step up the ladder
/// let gap  = ask.spread(to: mid)                                   // the spread, a Fraction
/// ```
public struct Price: Codable, Hashable, Comparable, Sendable, Stubbable {
    public let quote: AssetInstance
    public let base: AssetInstance
    /// Quote base units per whole base unit, times 10^9: the stored number, and the whole of the stored row with the
    /// two instances
    public let scaled: Int128

    // The decoder's and this library's; no public initializer takes `scaled` (2026-10-07).
    init(quote: AssetInstance, base: AssetInstance, scaled: Int128) {
        self.quote = quote
        self.base = base
        self.scaled = scaled
    }

    /// This much quote for one whole unit of `base`
    ///
    /// - Precondition: the quote's base units times 10^9 fit an `Int128`
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when `base` is not in `registry`
    public init(_ quote: Amount, per base: AssetInstance, in registry: AssetRegistry = .shared) throws {
        // A price whose base the statement does not hold could never produce a cost, so it is refused here.
        _ = try registry.decimals(of: base)
        self.init(quote: quote.instance, base: base, scaled: quote.baseUnits.timesExactly(.assetScale))
    }

    /// The price a fill states: this much quote for that much base, rounded toward zero at the scale
    ///
    /// - Precondition: `size` is positive
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when the size's instance is not in `registry`
    public init(_ quote: Amount, per size: Amount, in registry: AssetRegistry = .shared) throws {
        precondition(size.baseUnits > 0, "Price(_:per:) with a size that is not positive")
        let decimals = try registry.decimals(of: size.instance)

        // quote × 10^decimals × 10^9 ÷ size, toward zero. The product of the two powers can pass 10^38, so the
        // division is taken once at full width with its remainder and the remainder carried at the scale:
        // q × 10^9 + (r × 10^9 ÷ size) truncates exactly as the whole would, since q and r share a sign.
        let (whole, remainder) = quote.baseUnits.scaledWithRemainder(by: .powerOfTen(decimals), over: size.baseUnits)
        let fraction = remainder.scaled(by: .assetScale, over: size.baseUnits)
        self.init(quote: quote.instance, base: size.instance, scaled: whole.timesExactly(.assetScale) + fraction)
    }

    /// The cost of a size at this price, read against the statement's decimals for the base, rounded toward zero
    ///
    /// - Precondition: `size.instance` is this price's base
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when the base is not in `registry`
    public func cost(of size: Amount, in registry: AssetRegistry = .shared) throws -> Amount {
        requireOneInstance(size.instance, base, "Price.cost(of:)")
        let decimals = try registry.decimals(of: base)
        // scaled × size ÷ (10^9 × 10^decimals), at full width, toward zero.
        let baseUnits = scaled.scaled(by: size.baseUnits, overPowerOfTen: 9 + decimals)
        return Amount(baseUnits: baseUnits, of: quote)
    }

    /// Walks a step of the ladder; rounds toward zero
    public static func * (lhs: Self, rhs: Fraction) -> Self {
        Self(quote: lhs.quote, base: lhs.base, scaled: lhs.scaled.scaled(by: rhs.scaledNumerator, over: .assetScale))
    }

    /// So `min` and `max` order a ladder of candidate prices
    ///
    /// - Precondition: both prices share a base and a quote instance
    public static func < (lhs: Self, rhs: Self) -> Bool {
        requireOneInstance(lhs.base, rhs.base, "Price < (base)")
        requireOneInstance(lhs.quote, rhs.quote, "Price < (quote)")
        return lhs.scaled < rhs.scaled
    }

    /// How far this price is above `other`, as a fraction of `other`: (self − other) ÷ other; negative below it
    ///
    /// - Precondition: both prices share a base and a quote instance; `other` is not zero
    public func spread(to other: Self) -> Fraction {
        requireOneInstance(base, other.base, "Price.spread(to:) (base)")
        requireOneInstance(quote, other.quote, "Price.spread(to:) (quote)")
        precondition(!other.isZero, "Price.spread(to:) against a zero price")
        // (self − other) ÷ other at the scale, toward zero: the owner's reading of 2026-10-06 (OQ-C12), C5's example
        // `ask.spread(to: mid)` read as how far the ask is above the mid, relative to the mid.
        return .atScale((scaled - other.scaled).scaled(by: .assetScale, over: other.scaled))
    }

    public var isZero: Bool {
        scaled == 0
    }
}

// MARK: Stubs

extension Price {
    public static func stub() -> Self { .stub(scaled: 42 * 1_000_000_000) }

    // 42 quote base units per whole base unit, at the scale 10^9; the quote and the base are two reserved-fake
    // instances, so they are never one. Made by the decoder's initializer, so the stub needs no registry.
    public static func stub(
        quote: AssetInstance = .stub(),
        base: AssetInstance = .stub(address: "boulder-42"),
        scaled: Int128 = 42 * 1_000_000_000
    ) -> Self {
        .init(quote: quote, base: base, scaled: scaled)
    }
}
