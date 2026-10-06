// Price.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// Sealed as Fraction is: `scaledQuote` is the quote's base units per one whole unit of the base asset, times the one
// scale 10^9 (§ 9.5 of the protocols), so a price below one quote base unit is exact. No property vends it and no
// initializer takes it; the encoded shape is synthesized, undocumented, and pinned by the round-trip test alone.

/// An amount of a quote asset per one whole unit of a base asset: 65,000 USD per BTC
///
/// A price has two assets. The cost it produces is in the quote asset; the size it is applied to is in the base
/// asset; an ``Amount`` has one asset and cannot say either. It is held at a scale, so a price below one quote
/// base unit per whole base unit is exact.
///
/// ```swift
/// let mid  = Price(Amount(whole: 65_000, of: usd), per: btc)       // $65,000.00 / BTC
/// let size = Amount(baseUnits: 15_000_000, asset: btc)              // 0.15 BTC
/// let cost = mid.cost(of: size)                                    // $9,750.00, an Amount in usd, exact
/// let ask  = mid * (.one + Fraction(basisPoints: 5))               // one step up the ladder
/// let gap  = ask.spread(to: mid)                                   // the spread, a Fraction
///
/// let fill = Price(Amount(baseUnits: 4_000, asset: btc),            // 4,000 satoshis
///                  per: Amount(whole: 10_000, of: snek))           // for 10,000 SNEK: 0.4 satoshi each, exact
/// ```
public struct Price: Codable, Hashable, Comparable, Sendable, Stubbable {
    public let quote: Asset
    public let base: Asset

    // Quote base units per whole base unit, times 10^9.
    let scaledQuote: Int128

    private init(quote: Asset, base: Asset, scaledQuote: Int128) {
        self.quote = quote
        self.base = base
        self.scaledQuote = scaledQuote
    }

    /// This much quote for one whole unit of `base`
    public init(_ quote: Amount, per base: Asset) {
        self.init(quote: quote.asset, base: base, scaledQuote: quote.baseUnits.timesExactly(.assetScale))
    }

    /// The price a fill states: this much quote for that much base
    ///
    /// - Precondition: `size` is positive and of the base asset
    public init(_ quote: Amount, per size: Amount) {
        precondition(size.baseUnits > 0, "Price(_:per:) with a size that is not positive")

        // quote × 10^unitExponent × 10^9 ÷ size, toward zero. The product of the two powers can pass 10^38, so
        // the division is taken once at full width with its remainder and the remainder carried at the scale:
        // q × 10^9 + (r × 10^9 ÷ size) truncates exactly as the whole would, since q and r share a sign.
        let (whole, remainder) = quote.baseUnits.scaledWithRemainder(
            by: .powerOfTen(size.asset.unitExponent),
            over: size.baseUnits
        )
        let fraction = remainder.scaled(by: .assetScale, over: size.baseUnits)
        self.init(
            quote: quote.asset,
            base: size.asset,
            scaledQuote: whole.timesExactly(.assetScale) + fraction
        )
    }

    /// The cost of `size` at this price, in the quote asset, rounded toward zero
    ///
    /// - Precondition: `size.asset` is this price's base asset
    public func cost(of size: Amount) -> Amount {
        requireOneAsset(size.asset, base, "Price.cost(of:)")
        // scaledQuote × size ÷ (10^9 × 10^unitExponent), at full width, toward zero.
        let baseUnits = scaledQuote.scaled(by: size.baseUnits, overPowerOfTen: 9 + base.unitExponent)
        return Amount(baseUnits: baseUnits, asset: quote)
    }

    /// Walks a step of the ladder; rounds toward zero
    public static func * (lhs: Self, rhs: Fraction) -> Self {
        Self(
            quote: lhs.quote,
            base: lhs.base,
            scaledQuote: lhs.scaledQuote.scaled(by: rhs.scaledNumerator, over: .assetScale)
        )
    }

    /// So `min` and `max` order a ladder of candidate prices
    ///
    /// - Precondition: both prices share a base and a quote asset
    public static func < (lhs: Self, rhs: Self) -> Bool {
        requireOneAsset(lhs.base, rhs.base, "Price < (base)")
        requireOneAsset(lhs.quote, rhs.quote, "Price < (quote)")
        return lhs.scaledQuote < rhs.scaledQuote
    }

    /// How far this price is above `other`, as a fraction of `other`: (self − other) ÷ other; negative below it
    ///
    /// - Precondition: both prices share a base and a quote asset; `other` is not zero
    public func spread(to other: Self) -> Fraction {
        requireOneAsset(base, other.base, "Price.spread(to:) (base)")
        requireOneAsset(quote, other.quote, "Price.spread(to:) (quote)")
        precondition(!other.isZero, "Price.spread(to:) against a zero price")
        // (self − other) ÷ other at the scale, toward zero: the owner's reading of 2026-10-06 (OQ-C12), C5's example
        // `ask.spread(to: mid)` read as how far the ask is above the mid, relative to the mid.
        return .atScale((scaledQuote - other.scaledQuote).scaled(by: .assetScale, over: other.scaledQuote))
    }

    public var isZero: Bool {
        scaledQuote == 0
    }
}
