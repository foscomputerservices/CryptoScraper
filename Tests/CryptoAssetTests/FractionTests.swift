// FractionTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Fraction")
struct FractionTests {
    @Test func basisPointsPercentAndIntegerAgree() {
        #expect(Fraction(basisPoints: 25) == Fraction(percent: 0) + Fraction(basisPoints: 25))
        #expect(Fraction(basisPoints: 25) + Fraction(basisPoints: 75) == Fraction(percent: 1))
        #expect(Fraction(basisPoints: 100) == Fraction(percent: 1))
        #expect(Fraction(percent: 100) == .one)
        #expect(Fraction(integer: 1) == .one)
        #expect(Fraction(integer: 0) == .zero)
        #expect(Fraction(percent: 250) == Fraction(integer: 2) + Fraction(percent: 50))
    }

    @Test func twoIsMoreThanOneHundredFiftyPercent() {
        #expect(Fraction(integer: 2) > Fraction(percent: 150))
        #expect(Fraction(percent: 150) < Fraction(integer: 2))
    }

    @Test func aGainOf112Over100IsTwelvePercent() {
        let amountIn = Amount(whole: 100, of: .usdc)
        let amountOut = Amount(whole: 112, of: .usdc)
        #expect(Fraction(amountOut - amountIn, over: amountIn) == Fraction(percent: 12))
    }

    @Test func aLossIsNegative() {
        let amountIn = Amount(whole: 100, of: .usdc)
        let amountOut = Amount(whole: 97, of: .usdc)
        let loss = Fraction(amountOut - amountIn, over: amountIn)
        #expect(loss == Fraction(percent: -3))
        #expect(loss.isNegative)
        #expect(!loss.isZero)
    }

    @Test func fromTwoAmountsRoundsTowardZeroAtTheScale() {
        let third = Fraction(Amount(baseUnits: 1, asset: .usd), over: Amount(baseUnits: 3, asset: .usd))
        // 0.333333333, nine digits: three thirds fall one part in 10^9 short of one
        #expect(third + third + third < .one)
        #expect(.one - (third + third + third) == Fixtures.fraction(atScaled: 1))

        let negativeThird = Fraction(Amount(baseUnits: -1, asset: .usd), over: Amount(baseUnits: 3, asset: .usd))
        #expect(negativeThird == .zero - third)
    }

    @Test func aStopLevelReadsAsOneMinusTheDistance() {
        let entry = Amount(whole: 100, of: .usd)
        let distance = Fraction(percent: 2)
        #expect(entry * (.one - distance) == Amount(whole: 98, of: .usd))
    }

    @Test func zeroAsADivisorTrapsInAnAmountsDivision() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(whole: 1, of: .usd) / Fraction.zero
        }
    }

    @Test func aZeroWholeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(whole: 1, of: .usd), over: Amount.zero(of: .usd))
        }
    }
}
