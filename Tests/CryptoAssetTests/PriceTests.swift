// PriceTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Price")
struct PriceTests {
    @Test func aPriceBelowOneBaseUnitIsExact() {
        // 4,000 satoshis for 10,000 SNEK: 0.4 satoshi each
        let fill = Price(Amount(baseUnits: 4_000, asset: .btc), per: Amount(whole: 10_000, of: Fixtures.snek))
        #expect(fill.quote == .btc)
        #expect(fill.base == Fixtures.snek)
        #expect(fill.cost(of: Amount(whole: 10_000, of: Fixtures.snek)) == Amount(baseUnits: 4_000, asset: .btc))
        #expect(fill.cost(of: Amount(whole: 5, of: Fixtures.snek)) == Amount(baseUnits: 2, asset: .btc))
        #expect(fill.cost(of: Amount(whole: 1, of: Fixtures.snek)) == Amount.zero(of: .btc))
        #expect(!fill.isZero)
    }

    @Test func btcAt65000Dollars() {
        let mid = Price(Amount(baseUnits: 6_500_000, asset: .usd), per: .btc)   // 65000.00 USD per BTC
        let size = Amount(baseUnits: 15_000_000, asset: .btc)                     // 0.15 BTC
        #expect(mid.cost(of: size) == Amount(baseUnits: 975_000, asset: .usd))   // 9,750.00 USD
        #expect(mid == Price(Amount(whole: 65_000, of: .usd), per: .btc))
    }

    @Test func aFillPriceEqualsTheSamePricePerWholeUnit() {
        let fill = Price(Amount(whole: 9_750, of: .usd), per: Amount(baseUnits: 15_000_000, asset: .btc))
        #expect(fill == Price(Amount(whole: 65_000, of: .usd), per: .btc))
    }

    @Test func aCostRoundsTowardZero() {
        let mid = Price(Amount(baseUnits: 6_500_000, asset: .usd), per: .btc)
        // 1 satoshi at $65,000 is 0.065 cents
        #expect(mid.cost(of: Amount(baseUnits: 1, asset: .btc)) == Amount.zero(of: .usd))
        #expect(mid.cost(of: Amount(baseUnits: 100, asset: .btc)) == Amount(baseUnits: 6, asset: .usd))
        #expect(mid.cost(of: Amount(baseUnits: -100, asset: .btc)) == Amount(baseUnits: -6, asset: .usd))
    }

    @Test func aLadderOfFiveStepsOrders() {
        let mid = Price(Amount(whole: 65_000, of: .usd), per: .btc)
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
        let mid = Price(Amount(whole: 65_000, of: .usd), per: .btc)
        let ask = mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.cost(of: Amount(whole: 1, of: .btc)) == Amount(baseUnits: 6_503_250, asset: .usd))
        #expect(mid.spread(to: ask) == Fraction(basisPoints: 5))
        #expect(mid.spread(to: mid) == .zero)
        #expect(ask.spread(to: mid).isNegative)
    }

    @Test func aZeroSizeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 1, of: .usd), per: Amount.zero(of: .btc))
        }
    }

    @Test(.disabled("No CryptoAsset API takes text: belowBaseUnit is thrown by the public clients' decode (C3, C30), so this vector belongs to § 8.6"))
    func tenDigitsBelowTheQuotesBaseUnitThrowBelowBaseUnit() {}

    // § 9.5's headroom table at 10^9: the price, its cost of one whole BTC exact, and the multiple of the price
    // that still fits an Int128 beside the first that does not.

    @Test func headroomBTCInUSD() {
        let price = Price(Amount(whole: 65_000, of: .usd), per: .btc)
        #expect(price.cost(of: Amount(whole: 1, of: .btc)) == Amount(whole: 65_000, of: .usd))
        // ×2.6 × 10^22 of headroom: past what a Fraction(integer:) can say
        let widest = price * Fraction(integer: .max)
        #expect(Fraction(integer: 1) < price.spread(to: widest))
    }

    @Test func headroomBTCInUSDC() {
        let price = Price(Amount(whole: 65_000, of: .usdc), per: .btc)
        #expect(price.cost(of: Amount(whole: 1, of: .btc)) == Amount(whole: 65_000, of: .usdc))
        _ = price * Fraction(integer: 2_600_000_000_000_000_000)    // ×2.6 × 10^18 fits
    }

    @Test func headroomBTCInUSDCOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 65_000, of: .usdc), per: .btc) * Fraction(integer: 2_700_000_000_000_000_000)
        }
    }

    @Test func headroomBTCInETH() {
        let price = Price(Amount(whole: 25, of: .eth), per: .btc)
        #expect(price.cost(of: Amount(whole: 1, of: .btc)) == Amount(whole: 25, of: .eth))
        _ = price * Fraction(integer: 6_800_000_000)                // ×6.8 × 10^9 fits
    }

    @Test func headroomBTCInETHOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 25, of: .eth), per: .btc) * Fraction(integer: 6_900_000_000)
        }
    }

    @Test func headroomBTCInACheap18ExponentToken() {
        let price = Price(Amount(whole: 6_500_000_000, of: Fixtures.cheap), per: .btc)
        #expect(price.cost(of: Amount(whole: 1, of: .btc)) == Amount(whole: 6_500_000_000, of: Fixtures.cheap))
        _ = price * Fraction(integer: 26)                           // ×26 fits
    }

    @Test func headroomBTCInACheap18ExponentTokenOverflowsPastIt() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 6_500_000_000, of: Fixtures.cheap), per: .btc) * Fraction(integer: 27)
        }
    }
}
