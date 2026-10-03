// C4_Fraction.swift
//
// C4: a fraction, an exact ratio at a fixed scale, for a gain, a share, a slippage step, a stop distance,
// a leverage. R3, R7.
// The numerator and the scale are sealed, so a fraction's value is observed through equality, ordering and
// what it does to an Amount. The traps of its preconditions are in C6_BoundaryRule.swift.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Fraction — C4, R3, R7 behavioral")
struct C4_FractionTests {

    // MARK: Zero and one

    // C4: .zero is zero and not negative
    @Test func zeroIsZero() {
        #expect(Fraction.zero.isZero)
        #expect(Fraction.zero.isNegative == false)
    }

    // C4: .one is not zero and not negative
    @Test func oneIsNotZero() {
        #expect(Fraction.one.isZero == false)
        #expect(Fraction.one.isNegative == false)
        #expect(Fraction.zero < Fraction.one)
    }

    // MARK: Exact from basis points, a percent and an integer

    // C4: "From basis points, from a percent and from an integer it is exact": all three spell one
    @Test func oneIsTenThousandBasisPointsAHundredPercentAndTheIntegerOne() {
        #expect(Fraction(basisPoints: 10_000) == .one)
        #expect(Fraction(percent: 100) == .one)
        #expect(Fraction(integer: 1) == .one)
    }

    // C4: all three spell zero
    @Test func zeroIsZeroBasisPointsZeroPercentAndTheIntegerZero() {
        #expect(Fraction(basisPoints: 0) == .zero)
        #expect(Fraction(percent: 0) == .zero)
        #expect(Fraction(integer: 0) == .zero)
    }

    // C4: a percent is a hundred basis points
    @Test func twoPercentIsTwoHundredBasisPoints() {
        #expect(Fraction(percent: 2) == Fraction(basisPoints: 200))
    }

    // C4: a leverage of 2x is two hundred percent
    @Test func theIntegerTwoIsTwoHundredPercent() {
        #expect(Fraction(integer: 2) == Fraction(percent: 200))
        #expect(Fraction(integer: 2) == Fraction(basisPoints: 20_000))
    }

    // C4: a basis point is exact: applied to 10,000 base units it is one base unit
    @Test func oneBasisPointOfTenThousandIsOne() {
        #expect((Amount(baseUnits: 10_000, asset: Fake.fred) * Fraction(basisPoints: 1)).baseUnits == 1)
    }

    // C4: a slippage step of 25 basis points
    @Test func twentyFiveBasisPointsOfTenThousandIsTwentyFive() {
        #expect((Amount(baseUnits: 10_000, asset: Fake.fred) * Fraction(basisPoints: 25)).baseUnits == 25)
    }

    // C4: different fractions are not equal
    @Test func differentFractionsAreNotEqual() {
        #expect(Fraction(basisPoints: 25) != Fraction(basisPoints: 26))
    }

    // MARK: Sign

    // C4: a negative percent is negative
    @Test func aNegativePercentIsNegative() {
        #expect(Fraction(percent: -2).isNegative)
        #expect(Fraction(percent: -2).isZero == false)
        #expect(Fraction(percent: -2) < .zero)
    }

    // C4: a negative integer and negative basis points are negative
    @Test func aNegativeIntegerAndNegativeBasisPointsAreNegative() {
        #expect(Fraction(integer: -42).isNegative)
        #expect(Fraction(basisPoints: -42).isNegative)
    }

    // MARK: + and -

    // C4: "+ and - exist because T78's level reads as .one - distance"
    @Test func oneLessTwoPercentIsNinetyEightPercent() {
        #expect(Fraction.one - Fraction(percent: 2) == Fraction(percent: 98))
    }

    // C4: + adds exactly
    @Test func basisPointsAddExactly() {
        #expect(Fraction(basisPoints: 25) + Fraction(basisPoints: 25) == Fraction(basisPoints: 50))
        #expect(Fraction(percent: 50) + Fraction(percent: 50) == .one)
    }

    // C4: - can go below zero
    @Test func zeroLessOneIsNegative() {
        let minusOne = Fraction.zero - .one
        #expect(minusOne.isNegative)
        #expect(minusOne == Fraction(integer: -1))
    }

    // C4: + and - undo each other
    @Test func addingThenSubtractingIsIdentity() {
        let step = Fraction(basisPoints: 25)
        #expect(Fraction(percent: 2) + step - step == Fraction(percent: 2))
    }

    // MARK: Ordering

    // C4: < orders fractions
    @Test func fractionsOrderByValue() {
        #expect(Fraction(basisPoints: 25) < Fraction(percent: 1))
        #expect(Fraction(percent: 1) < Fraction(integer: 1))
        #expect((Fraction(integer: 1) < Fraction(percent: 1)) == false)
    }

    // C4: sorted orders fractions of mixed spelling
    @Test func sortedOrdersFractions() {
        let fractions = [Fraction(integer: 2), Fraction(percent: -2), Fraction(basisPoints: 25), Fraction.zero]
        #expect(fractions.sorted() == [Fraction(percent: -2), .zero, Fraction(basisPoints: 25), Fraction(integer: 2)])
    }

    // MARK: From two amounts: a division, rounded toward zero at the scale

    // C4, R3: Fraction(part, over: whole) of an exact ratio is exact
    @Test func halfOfAnAmountIsFiftyPercent() {
        let fraction = Fraction(Amount(baseUnits: 21, asset: Fake.fred), over: Amount(baseUnits: 42, asset: Fake.fred))
        #expect(fraction == Fraction(percent: 50))
    }

    // C4: a part equal to the whole is one
    @Test func aPartEqualToTheWholeIsOne() {
        let amount = Amount(whole: 42, of: Fake.barney)
        #expect(Fraction(amount, over: amount) == .one)
    }

    // C4: a part larger than the whole is above one
    @Test func aPartLargerThanTheWholeIsAboveOne() {
        let fraction = Fraction(Amount(baseUnits: 84, asset: Fake.fred), over: Amount(baseUnits: 42, asset: Fake.fred))
        #expect(fraction == Fraction(integer: 2))
    }

    // C4: a zero part is zero
    @Test func aZeroPartIsZero() {
        #expect(Fraction(.zero(of: Fake.fred), over: Amount(baseUnits: 42, asset: Fake.fred)).isZero)
    }

    // C4: a negative part is negative (a loss)
    @Test func aNegativePartIsNegative() {
        let loss = Fraction(Amount(baseUnits: -21, asset: Fake.fred), over: Amount(baseUnits: 42, asset: Fake.fred))
        #expect(loss == Fraction(percent: -50))
    }

    // C4: "from two amounts it is a division and rounds toward zero at the scale": a third is 0.333333333
    @Test func aThirdRoundsTowardZeroAtNineDigits() {
        let third = Fraction(Amount(baseUnits: 1, asset: Fake.fred), over: Amount(baseUnits: 3, asset: Fake.fred))
        #expect((Amount(baseUnits: 3_000_000_000, asset: Fake.fred) * third).baseUnits == 999_999_999)
        #expect(third + third + third < .one)
    }

    // C4: rounding toward zero holds for a negative ratio
    @Test func aNegativeThirdRoundsTowardZero() {
        let third = Fraction(Amount(baseUnits: -1, asset: Fake.fred), over: Amount(baseUnits: 3, asset: Fake.fred))
        #expect((Amount(baseUnits: 3_000_000_000, asset: Fake.fred) * third).baseUnits == -999_999_999)
        #expect(Fraction(integer: -1) < third + third + third)
    }

    // C4: "exact to nine fraction digits": one part in 10^9 survives
    @Test func onePartInABillionIsExact() {
        let tiny = Fraction(Amount(baseUnits: 1, asset: Fake.fred), over: Amount(baseUnits: pow10(9), asset: Fake.fred))
        #expect(tiny.isZero == false)
        #expect((Amount(baseUnits: pow10(9), asset: Fake.fred) * tiny).baseUnits == 1)
    }

    // C4: "and no further": one part in 10^10 rounds to zero
    @Test func onePartInTenBillionRoundsToZero() {
        let tinier = Fraction(Amount(baseUnits: 1, asset: Fake.fred), over: Amount(baseUnits: pow10(10), asset: Fake.fred))
        #expect(tinier.isZero)
    }

    // C4 with C2: a named and an unnamed declaration of one asset make a fraction without trapping
    @Test func aFractionOfANamedAndAnUnnamedDeclarationIsMade() {
        let fraction = Fraction(Amount(baseUnits: 21, asset: Fake.fredNamed), over: Amount(baseUnits: 42, asset: Fake.fred))
        #expect(fraction == Fraction(percent: 50))
    }

    // C4: a ratio of amounts at full width
    @Test func aRatioOfAmountsBeyondInt64IsExact() {
        let fraction = Fraction(Amount(baseUnits: pow10(30), asset: Fake.bedrock),
                                over: Amount(baseUnits: 4 * pow10(30), asset: Fake.bedrock))
        #expect(fraction == Fraction(basisPoints: 2_500))
    }

    // MARK: Hashing

    // R10: equal fractions hash alike
    @Test func equalFractionsHashAlike() {
        #expect(Set([Fraction(percent: 2), Fraction(basisPoints: 200)]).count == 1)
    }
}
