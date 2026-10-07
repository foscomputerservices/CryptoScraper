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

    @Test func aGainOf112Over100IsTwelvePercent() throws {
        let amountIn = try Amount(whole: 100, of: Fixtures.usdc, in: Fixtures.registry())
        let amountOut = try Amount(whole: 112, of: Fixtures.usdc, in: Fixtures.registry())
        #expect(Fraction(amountOut - amountIn, over: amountIn) == Fraction(percent: 12))
    }

    @Test func aLossIsNegative() throws {
        let amountIn = try Amount(whole: 100, of: Fixtures.usdc, in: Fixtures.registry())
        let amountOut = try Amount(whole: 97, of: Fixtures.usdc, in: Fixtures.registry())
        let loss = Fraction(amountOut - amountIn, over: amountIn)
        #expect(loss == Fraction(percent: -3))
        #expect(loss.isNegative)
        #expect(!loss.isZero)
    }

    @Test func fromTwoAmountsRoundsTowardZeroAtTheScale() {
        let third = Fraction(Amount(baseUnits: 1, of: Fixtures.usd), over: Amount(baseUnits: 3, of: Fixtures.usd))
        // 0.333333333, nine digits: three thirds fall one part in 10^9 short of one
        #expect(third + third + third < .one)
        #expect(.one - (third + third + third) == Fixtures.fraction(atScaled: 1))

        let negativeThird = Fraction(Amount(baseUnits: -1, of: Fixtures.usd), over: Amount(baseUnits: 3, of: Fixtures.usd))
        #expect(negativeThird == .zero - third)
    }

    @Test func aStopLevelReadsAsOneMinusTheDistance() throws {
        let entry = try Amount(whole: 100, of: Fixtures.usd, in: Fixtures.registry())
        let distance = Fraction(percent: 2)
        #expect(try entry * (.one - distance) == Amount(whole: 98, of: Fixtures.usd, in: Fixtures.registry()))
    }

    @Test func zeroAsADivisorTrapsInAnAmountsDivision() async {
        await #expect(processExitsWith: .failure) {
            _ = try! Amount(whole: 1, of: Fixtures.usd, in: Fixtures.registry()) / Fraction.zero
        }
    }

    @Test func aZeroWholeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(try! Amount(whole: 1, of: Fixtures.usd, in: Fixtures.registry()), over: Amount.zero(of: Fixtures.usd))
        }
    }
}
