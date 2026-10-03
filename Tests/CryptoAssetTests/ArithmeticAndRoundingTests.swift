// ArithmeticAndRoundingTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Testing

@Suite("Arithmetic and rounding")
struct ArithmeticAndRoundingTests {
    @Test func plusAndMinusAreExactNearTheTop() {
        let a = Amount(baseUnits: .max - 1, asset: .usd)
        let one = Amount(baseUnits: 1, asset: .usd)
        #expect((a + one).baseUnits == Int128.max)
        #expect((a - one).baseUnits == Int128.max - 2)
        #expect((-a).baseUnits == -(Int128.max - 1))
    }

    @Test func halfOfAnOddPositiveRoundsTowardZero() {
        #expect((Amount(baseUnits: 101, asset: .usd) * Fraction(percent: 50)).baseUnits == 50)
    }

    @Test func halfOfAnOddNegativeRoundsTowardZeroNotDown() {
        #expect((Amount(baseUnits: -101, asset: .usd) * Fraction(percent: 50)).baseUnits == -50)
    }

    @Test func divisionRoundsTowardZero() {
        #expect((Amount(baseUnits: 101, asset: .usd) / Fraction(integer: 2)).baseUnits == 50)
        #expect((Amount(baseUnits: -101, asset: .usd) / Fraction(integer: 2)).baseUnits == -50)
        #expect((Amount(baseUnits: 100, asset: .usd) / Fraction(integer: 3)).baseUnits == 33)
        #expect((Amount(baseUnits: -100, asset: .usd) / Fraction(integer: 3)).baseUnits == -33)
        #expect((Amount(baseUnits: 100, asset: .usd) / Fraction(percent: 50)).baseUnits == 200)
    }

    @Test func dividingByZeroTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 100, asset: .usd) / Fraction.zero
        }
    }

    @Test func theFullWidthVectorIsExact() {
        // 10^30 base units of an 18-exponent asset (a trillion ETH in wei) times a fraction at scale 10^9:
        // the intermediate 10^39 does not fit a single-width Int128 multiply.
        let (_, overflow) = Fixtures.tenToThe30.multipliedReportingOverflow(by: Fixtures.tenToThe9)
        #expect(overflow)

        let trillionEther = Amount(baseUnits: Fixtures.tenToThe30, asset: .eth)
        #expect((trillionEther * Fraction(percent: 50)).baseUnits == Fixtures.tenToThe30 / 2)
        #expect((trillionEther * Fraction(basisPoints: 1)).baseUnits == Fixtures.tenToThe30 / 10_000)
        #expect((trillionEther / Fraction(integer: 4)).baseUnits == Fixtures.tenToThe30 / 4)

        let odd = Amount(baseUnits: Fixtures.tenToThe30 + 1, asset: .eth)
        #expect((odd * Fraction(percent: 50)).baseUnits == Fixtures.tenToThe30 / 2)
        #expect(((-odd) * Fraction(percent: 50)).baseUnits == -(Fixtures.tenToThe30 / 2))
    }

    @Test func zeroAndSign() {
        #expect(Amount.zero(of: .btc).isZero)
        #expect(Amount.zero(of: .btc).asset == .btc)
        #expect(Amount(baseUnits: -1, asset: .btc).isNegative)
        #expect(!Amount(baseUnits: 0, asset: .btc).isNegative)
    }

    @Test func orderWithinOneAsset() {
        let small = Amount(baseUnits: 1, asset: .btc)
        let large = Amount(baseUnits: 2, asset: .btc)
        #expect(small < large)
        #expect(max(small, large) == large)
        #expect([large, small].sorted() == [small, large])
    }
}
