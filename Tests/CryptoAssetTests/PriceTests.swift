// PriceTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// Every price and cost below reads the fixtures' registry: the library's declarations and the bedrock:42 fakes.
private let registry = Fixtures.registry()

private func whole(_ count: Int, _ instance: AssetInstance) -> Amount {
    do { return try Amount(whole: count, of: instance, in: registry) } catch { preconditionFailure("\(error)") }
}

private func quoted(_ quote: Amount, per base: AssetInstance) -> Price {
    do { return try Price(quote, per: base, in: registry) } catch { preconditionFailure("\(error)") }
}

private func quoted(_ quote: Amount, per size: Amount) -> Price {
    do { return try Price(quote, per: size, in: registry) } catch { preconditionFailure("\(error)") }
}

private extension Price {
    func cost(_ size: Amount) -> Amount {
        do { return try cost(of: size, in: registry) } catch { preconditionFailure("\(error)") }
    }
}

@Suite("Price")
struct PriceTests {
    @Test func aPriceBelowOneBaseUnitIsExact() {
        // 4,000 satoshis for 10,000 SNEK: 0.4 satoshi each
        let fill = quoted(Amount(baseUnits: 4_000, of: Fixtures.btc), per: whole(10_000, Fixtures.snek))
        #expect(fill.quote == Fixtures.btc)
        #expect(fill.base == Fixtures.snek)
        #expect(fill.cost(whole(10_000, Fixtures.snek)) == Amount(baseUnits: 4_000, of: Fixtures.btc))
        #expect(fill.cost(whole(5, Fixtures.snek)) == Amount(baseUnits: 2, of: Fixtures.btc))
        #expect(fill.cost(whole(1, Fixtures.snek)) == Amount.zero(of: Fixtures.btc))
        #expect(!fill.isZero)
    }

    @Test func btcAt65000Dollars() {
        let mid = quoted(Amount(baseUnits: 6_500_000, of: Fixtures.usd), per: Fixtures.btc)   // 65000.00 USD per BTC
        let size = Amount(baseUnits: 15_000_000, of: Fixtures.btc)                     // 0.15 BTC
        #expect(mid.cost(size) == Amount(baseUnits: 975_000, of: Fixtures.usd))   // 9,750.00 USD
        #expect(mid == quoted(whole(65_000, Fixtures.usd), per: Fixtures.btc))
    }

    @Test func aFillPriceEqualsTheSamePricePerWholeUnit() {
        let fill = quoted(whole(9_750, Fixtures.usd), per: Amount(baseUnits: 15_000_000, of: Fixtures.btc))
        #expect(fill == quoted(whole(65_000, Fixtures.usd), per: Fixtures.btc))
    }

    @Test func aCostRoundsTowardZero() {
        let mid = quoted(Amount(baseUnits: 6_500_000, of: Fixtures.usd), per: Fixtures.btc)
        // 1 satoshi at $65,000 is 0.065 cents
        #expect(mid.cost(Amount(baseUnits: 1, of: Fixtures.btc)) == Amount.zero(of: Fixtures.usd))
        #expect(mid.cost(Amount(baseUnits: 100, of: Fixtures.btc)) == Amount(baseUnits: 6, of: Fixtures.usd))
        #expect(mid.cost(Amount(baseUnits: -100, of: Fixtures.btc)) == Amount(baseUnits: -6, of: Fixtures.usd))
    }

    @Test func aLadderOfFiveStepsOrders() {
        let mid = quoted(whole(65_000, Fixtures.usd), per: Fixtures.btc)
        let step = Fraction.one + Fraction(basisPoints: 5)
        var ladder = [mid]
        for _ in 1..<5 {
            ladder.append(ladder.last! * step)
        }
        for (lower, higher) in zip(ladder, ladder.dropFirst()) {
            #expect(lower < higher)
        }
        #expect([ladder[3], ladder[0], ladder[4], ladder[2], ladder[1]].sorted() == ladder)
        #expect(ladder.min() == mid)
        #expect(ladder.max() == ladder[4])
    }

    @Test func theSpreadOfAskOverMidIsTheStep() {
        let mid = quoted(whole(65_000, Fixtures.usd), per: Fixtures.btc)
        let ask = mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.cost(whole(1, Fixtures.btc)) == Amount(baseUnits: 6_503_250, of: Fixtures.usd))
        // OQ-C12, the owner's reading of 2026-10-06: the ask's spread to the mid is how far the ask is above the mid
        #expect(ask.spread(to: mid) == Fraction(basisPoints: 5))
        #expect(mid.spread(to: mid) == .zero)
        #expect(mid.spread(to: ask).isNegative)
    }

    @Test func aZeroSizeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = quoted(whole(1, Fixtures.usd), per: Amount.zero(of: Fixtures.btc))
        }
    }

    @Test(.disabled("No CryptoAsset API takes text: belowBaseUnit is thrown by the public clients' decode (C3, C30), so this vector belongs to § 8.6"))
    func tenDigitsBelowTheQuotesBaseUnitThrowBelowBaseUnit() {}

    // § 9.5's headroom table at 10^9: the price, its cost of one whole BTC exact, and the multiple of the price
    // that still fits an Int128 beside the first that does not.

    @Test func headroomBTCInUSD() {
        let price = quoted(whole(65_000, Fixtures.usd), per: Fixtures.btc)
        #expect(price.cost(whole(1, Fixtures.btc)) == whole(65_000, Fixtures.usd))
        // ×2.6 × 10^22 of headroom: past what a Fraction(integer:) can say
        let widest = price * Fraction(integer: .max)
        #expect(Fraction(integer: 1) < widest.spread(to: price))
    }

    @Test func headroomBTCInUSDC() {
        let price = quoted(whole(65_000, Fixtures.usdc), per: Fixtures.btc)
        #expect(price.cost(whole(1, Fixtures.btc)) == whole(65_000, Fixtures.usdc))
        _ = price * Fraction(integer: 2_600_000_000_000_000_000)    // ×2.6 × 10^18 fits
    }

    @Test func headroomBTCInUSDCOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = quoted(whole(65_000, Fixtures.usdc), per: Fixtures.btc) * Fraction(integer: 2_700_000_000_000_000_000)
        }
    }

    @Test func headroomBTCInETH() {
        let price = quoted(whole(25, Fixtures.eth), per: Fixtures.btc)
        #expect(price.cost(whole(1, Fixtures.btc)) == whole(25, Fixtures.eth))
        _ = price * Fraction(integer: 6_800_000_000)                // ×6.8 × 10^9 fits
    }

    @Test func headroomBTCInETHOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = quoted(whole(25, Fixtures.eth), per: Fixtures.btc) * Fraction(integer: 6_900_000_000)
        }
    }

    @Test func headroomBTCInACheap18ExponentToken() {
        let price = quoted(whole(6_500_000_000, Fixtures.cheap), per: Fixtures.btc)
        #expect(price.cost(whole(1, Fixtures.btc)) == whole(6_500_000_000, Fixtures.cheap))
        _ = price * Fraction(integer: 26)                           // ×26 fits
    }

    @Test func headroomBTCInACheap18ExponentTokenOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = quoted(whole(6_500_000_000, Fixtures.cheap), per: Fixtures.btc) * Fraction(integer: 27)
        }
    }

    // The top decade of the cost's divisor: a 30-exponent base asset divides the full-width product by 10^39, and a
    // result between Int128.max ÷ 10 and Int128.max is exact, with no intermediate quotient that must fit.

    private static let thirtyExponent = Fixtures.thirty

    // A price whose scaled quote is 1.7 × 10^38: 1.7 × 10^37 USD base units for 10^38 base units of the asset.
    private static func priceNearTheTop(of base: AssetInstance) -> Price {
        quoted(Amount(baseUnits: 17_000_000_000_000_000_000_000_000_000_000_000_000, of: Fixtures.usd),
              per: Amount(baseUnits: 100_000_000_000_000_000_000_000_000_000_000_000_000, of: base))
    }

    @Test func costAtADivisorOfTenToThe39IsExactAboveAnIntMaxTenth() {
        let price = Self.priceNearTheTop(of: Self.thirtyExponent)
        // 1.7 × 10^38 × 1.5 × 10^38 ÷ 10^39 = 2.55 × 10^37, above Int128.max ÷ 10 (1.7 × 10^37)
        let size = Amount(baseUnits: 150_000_000_000_000_000_000_000_000_000_000_000_000, of: Self.thirtyExponent)
        let expected: Int128 = 25_500_000_000_000_000_000_000_000_000_000_000_000
        #expect(expected > Int128.max / 10)
        #expect(price.cost(size) == Amount(baseUnits: expected, of: Fixtures.usd))
        // the sign and the truncation toward zero hold at the top decade
        #expect(price.cost(Amount(baseUnits: -size.baseUnits, of: Self.thirtyExponent))
                == Amount(baseUnits: -expected, of: Fixtures.usd))
        #expect(price.cost(Amount(baseUnits: size.baseUnits + 1, of: Self.thirtyExponent))
                == Amount(baseUnits: expected, of: Fixtures.usd))
        #expect(price.cost(Amount(baseUnits: -size.baseUnits - 1, of: Self.thirtyExponent))
                == Amount(baseUnits: -expected, of: Fixtures.usd))
    }

    @Test func costAtADivisorOfTenToThe39AtTheWidestOperands() {
        let price = Self.priceNearTheTop(of: Self.thirtyExponent)
        let widest = Amount(baseUnits: .max, of: Self.thirtyExponent)
        // 17 × 10^37 × (2^127 − 1) ÷ 10^39, by hand: 17 × 170141183460469231731687303715884105727 ÷ 100
        #expect(price.cost(widest) == Amount(baseUnits: 28_924_001_188_279_769_394_386_841_631_700_297_973, of: Fixtures.usd))
        let widestNegative = Amount(baseUnits: .min, of: Self.thirtyExponent)
        #expect(price.cost(widestNegative) == Amount(baseUnits: -28_924_001_188_279_769_394_386_841_631_700_297_973, of: Fixtures.usd))
    }

    // One step past Int128.max, at the divisor below it: a 29-exponent asset divides by 10^38.
    @Test func costPastInt128MaxStillTraps() async {
        await #expect(processExitsWith: .failure) {
            let base = Fixtures.twentyNine
            // a scaled quote of 1.7 × 10^38 again, at the exponent whose divisor is 10^38
            let price = quoted(Amount(baseUnits: 170_000_000_000_000_000_000_000_000_000_000_000_000, of: Fixtures.usd),
                              per: Amount(baseUnits: 100_000_000_000_000_000_000_000_000_000_000_000_000, of: base))
            _ = price.cost(Amount(baseUnits: .max, of: base))
        }
    }
}
