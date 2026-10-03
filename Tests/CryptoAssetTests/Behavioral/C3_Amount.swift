// C3_Amount.swift
//
// C3: an amount, an exact count of base units with its asset, converting exactly to and from named units as
// counts. R2, R3, R9, R10.
// The traps of C3's preconditions live in C6_BoundaryRule.swift.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Amount — C3, R2, R3 behavioral")
struct C3_AmountTests {

    // MARK: Making an amount

    // C3: init(baseUnits:asset:) keeps the count and the asset
    @Test func anAmountKeepsItsBaseUnitsAndItsAsset() {
        let amount = Amount(baseUnits: 42, asset: Fake.fred)
        #expect(amount.baseUnits == 42)
        #expect(amount.asset == Fake.fred)
    }

    // C3: "A whole number of whole units, exactly"
    @Test func wholeUnitsAreTenToTheExponentBaseUnitsEach() {
        #expect(Amount(whole: 42, of: Fake.fred).baseUnits == 420_000)
        #expect(Amount(whole: 42, of: Fake.barney).baseUnits == 4_200_000_000)
    }

    // C3: a negative whole number is exact too
    @Test func aNegativeWholeNumberIsExact() {
        #expect(Amount(whole: -42, of: Fake.fred).baseUnits == -420_000)
    }

    // C3, R9: at exponent 0 a whole unit is one base unit
    @Test func atExponentZeroAWholeUnitIsOneBaseUnit() {
        #expect(Amount(whole: 42, of: Fake.dino).baseUnits == 42)
    }

    // C3, R2: at exponent 30 the count is held at full Int128 width, beyond Int64
    @Test func atExponentThirtyTheCountIsExactBeyondInt64() {
        #expect(Amount(whole: 42, of: Fake.bedrock).baseUnits == 42 * pow10(30))
        #expect(Amount(whole: -42, of: Fake.bedrock).baseUnits == -42 * pow10(30))
    }

    // MARK: Named units, both ways, as counts

    // C3: "A count of a named unit, exactly": a unit between
    @Test func aCountOfAUnitBetweenIsExact() throws {
        let amount = try Amount(count: 5, in: Fake.pebble, of: Fake.slate)
        #expect(amount.baseUnits == 5 * pow10(9))
        #expect(amount.asset == Fake.slate)
    }

    // C3: a count of the whole unit is the same as whole units
    @Test func aCountOfTheWholeUnitEqualsWholeUnits() throws {
        let amount = try Amount(count: 42, in: Fake.slate.wholeUnit, of: Fake.slate)
        #expect(amount == Amount(whole: 42, of: Fake.slate))
    }

    // C3: a count of the base unit is that many base units
    @Test func aCountOfTheBaseUnitIsThatManyBaseUnits() throws {
        let gravel = try #require(Fake.slate.baseUnit)
        let amount = try Amount(count: 42, in: gravel, of: Fake.slate)
        #expect(amount.baseUnits == 42)
    }

    // C3: a negative count is exact
    @Test func aNegativeCountIsExact() throws {
        let amount = try Amount(count: -5, in: Fake.pebble, of: Fake.slate)
        #expect(amount.baseUnits == -5 * pow10(9))
    }

    // C3: "Throws unitOutOfRange when unit is not the asset's": an exponent past the asset's
    @Test func aCountInAUnitPastTheAssetsExponentIsRefused() {
        let boulder = Asset.Unit(name: "boulder", exponent: 19)
        #expect(throws: AssetError.unitOutOfRange(boulder)) {
            try Amount(count: 1, in: boulder, of: Fake.slate)
        }
    }

    // C3: "Throws unitOutOfRange when unit is not the asset's": another asset's unit, inside the range
    // UNRATIFIED-CLARIFICATION: "not the asset's" is read as membership in the asset's units, not only the
    // exponent's range; the stricter reading is tested.
    @Test func aCountInAnotherAssetsUnitIsRefused() {
        let barneyWhole = Fake.barney.wholeUnit
        #expect(throws: AssetError.unitOutOfRange(barneyWhole)) {
            try Amount(count: 1, in: barneyWhole, of: Fake.slate)
        }
    }

    // C3: "The quantity read in a named unit, exactly: the whole count of that unit and the base units left over"
    @Test func readingInAUnitGivesTheCountAndTheRemainder() {
        let amount = Amount(baseUnits: 5 * pow10(9) + 42, asset: Fake.slate)
        let reading = amount.count(in: Fake.pebble)
        #expect(reading.count == 5)
        #expect(reading.remainder == 42)
    }

    // C3: an exact multiple leaves no remainder
    @Test func readingAnExactMultipleLeavesNoRemainder() {
        let reading = Amount(whole: 42, of: Fake.slate).count(in: Fake.slate.wholeUnit)
        #expect(reading.count == 42)
        #expect(reading.remainder == 0)
    }

    // C3: reading in the base unit is the count itself
    @Test func readingInTheBaseUnitIsTheCountItself() throws {
        let gravel = try #require(Fake.slate.baseUnit)
        let reading = Amount(baseUnits: 42, asset: Fake.slate).count(in: gravel)
        #expect(reading.count == 42)
        #expect(reading.remainder == 0)
    }

    // C3: less than one of the unit reads as zero and all remainder
    @Test func lessThanOneUnitReadsAsZeroAndARemainder() {
        let reading = Amount(baseUnits: 42, asset: Fake.slate).count(in: Fake.pebble)
        #expect(reading.count == 0)
        #expect(reading.remainder == 42)
    }

    // C3: "Rounding is toward zero everywhere, for a positive and a negative quantity alike"
    // UNRATIFIED-CLARIFICATION: the remainder of a negative quantity is read as carrying the quantity's sign.
    @Test func readingANegativeQuantityRoundsTowardZero() {
        let amount = Amount(baseUnits: -(5 * pow10(9) + 42), asset: Fake.slate)
        let reading = amount.count(in: Fake.pebble)
        #expect(reading.count == -5)
        #expect(reading.remainder == -42)
    }

    // C3: the two directions agree: count then read gives the count back
    @Test func aCountReadsBackAsItself() throws {
        let amount = try Amount(count: 42, in: Fake.pebble, of: Fake.slate)
        let reading = amount.count(in: Fake.pebble)
        #expect(reading.count == 42)
        #expect(reading.remainder == 0)
    }

    // MARK: Equality is total

    // C3: "== is total": same asset, same count
    @Test func amountsOfOneAssetAndOneCountAreEqual() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) == Amount(baseUnits: 42, asset: Fake.fred))
    }

    // C3: same asset, different count
    @Test func amountsOfOneAssetAndDifferentCountsAreNotEqual() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) != Amount(baseUnits: 41, asset: Fake.fred))
    }

    // C3: "two amounts of different assets are not equal and do not trap"
    @Test func amountsOfDifferentAssetsAreNotEqualAndDoNotTrap() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) != Amount(baseUnits: 42, asset: Fake.dino))
    }

    // C3 with C2's identity: one symbol at two exponents is two assets
    @Test func amountsOfOneSymbolAtTwoExponentsAreNotEqual() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) != Amount(baseUnits: 42, asset: Fake.fredAtEight))
    }

    // C2, C3: units are not identity, so amounts of a named and an unnamed declaration are equal and hash alike
    @Test func amountsOfANamedAndAnUnnamedDeclarationAreEqual() {
        let bare = Amount(baseUnits: 42, asset: Fake.fred)
        let named = Amount(baseUnits: 42, asset: Fake.fredNamed)
        #expect(bare == named)
        #expect(Set([bare, named]).count == 1)
    }

    // R10: amounts of different assets are distinct in a set
    @Test func amountsOfDifferentAssetsAreDistinctInASet() {
        let set: Set<Amount> = [Amount(baseUnits: 42, asset: Fake.fred), Amount(baseUnits: 42, asset: Fake.dino)]
        #expect(set.count == 2)
    }

    // MARK: Arithmetic, exact

    // C3, R3: amount + amount of one asset is exact
    @Test func addingTwoAmountsOfOneAssetIsExact() {
        let sum = Amount(baseUnits: 42, asset: Fake.fred) + Amount(baseUnits: -84, asset: Fake.fred)
        #expect(sum == Amount(baseUnits: -42, asset: Fake.fred))
    }

    // C3, R3: amount - amount of one asset is exact
    @Test func subtractingTwoAmountsOfOneAssetIsExact() {
        let difference = Amount(whole: 42, of: Fake.fred) - Amount(baseUnits: 1, asset: Fake.fred)
        #expect(difference.baseUnits == 419_999)
    }

    // C2, C3: amounts of a named and an unnamed declaration of one asset add
    @Test func amountsOfANamedAndAnUnnamedDeclarationAdd() {
        let sum = Amount(baseUnits: 42, asset: Fake.fred) + Amount(baseUnits: 42, asset: Fake.fredNamed)
        #expect(sum.baseUnits == 84)
    }

    // C3: arithmetic at full width, beyond Int64
    @Test func arithmeticBeyondInt64IsExact() {
        let big = Amount(baseUnits: pow10(30), asset: Fake.bedrock)
        let sum = big + Amount(baseUnits: 42, asset: Fake.bedrock)
        #expect(sum.baseUnits == pow10(30) + 42)
    }

    // C3: prefix minus negates
    @Test func negatingAnAmountFlipsItsSign() {
        let amount = Amount(baseUnits: 42, asset: Fake.fred)
        #expect((-amount).baseUnits == -42)
        #expect((-amount).asset == Fake.fred)
        #expect(-(-amount) == amount)
    }

    // MARK: Scaling by a fraction

    // C3: "Scales exactly": an exact half
    @Test func timesAFractionScalesExactly() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) * Fraction(percent: 50) == Amount(baseUnits: 21, asset: Fake.fred))
    }

    // C3: "rounds toward zero, discarding what is below one base unit": positive
    @Test func timesAFractionRoundsAPositiveResultTowardZero() {
        #expect(Amount(baseUnits: 21, asset: Fake.fred) * Fraction(percent: 50) == Amount(baseUnits: 10, asset: Fake.fred))
    }

    // C3: "Rounding is toward zero everywhere, for a positive and a negative quantity alike"
    @Test func timesAFractionRoundsANegativeResultTowardZero() {
        #expect(Amount(baseUnits: -21, asset: Fake.fred) * Fraction(percent: 50) == Amount(baseUnits: -10, asset: Fake.fred))
    }

    // C3: below one base unit is discarded
    @Test func timesAFractionBelowOneBaseUnitIsZero() {
        #expect((Amount(baseUnits: 1, asset: Fake.fred) * Fraction(basisPoints: 1)).isZero)
    }

    // C3: times a fraction keeps the asset
    @Test func timesAFractionKeepsTheAsset() {
        #expect((Amount(baseUnits: 42, asset: Fake.barney) * Fraction(basisPoints: 25)).asset == Fake.barney)
    }

    // C3: times a negative fraction
    @Test func timesANegativeFractionFlipsTheSign() {
        let negativeHalf = Fraction.zero - Fraction(percent: 50)
        #expect(Amount(baseUnits: 42, asset: Fake.fred) * negativeHalf == Amount(baseUnits: -21, asset: Fake.fred))
    }

    // C3: divided by a fraction, exact
    @Test func dividedByAFractionScalesExactly() {
        #expect(Amount(baseUnits: 42, asset: Fake.fred) / Fraction(integer: 2) == Amount(baseUnits: 21, asset: Fake.fred))
        #expect(Amount(baseUnits: 42, asset: Fake.fred) / Fraction(percent: 50) == Amount(baseUnits: 84, asset: Fake.fred))
    }

    // C3: divided by a fraction rounds toward zero, positive
    @Test func dividedByAFractionRoundsAPositiveResultTowardZero() {
        #expect(Amount(baseUnits: 43, asset: Fake.fred) / Fraction(integer: 2) == Amount(baseUnits: 21, asset: Fake.fred))
    }

    // C3: divided by a fraction rounds toward zero, negative
    @Test func dividedByAFractionRoundsANegativeResultTowardZero() {
        #expect(Amount(baseUnits: -43, asset: Fake.fred) / Fraction(integer: 2) == Amount(baseUnits: -21, asset: Fake.fred))
    }

    // C3: "Scaling never overflows an intermediate: the product is taken at full width"
    @Test func timesAFractionNeverOverflowsAnIntermediate() {
        let huge = Amount(baseUnits: pow10(37), asset: Fake.bedrock)
        #expect((huge * Fraction(percent: 50)).baseUnits == 5 * pow10(36))
    }

    // C3: "Scaling never overflows an intermediate", division
    @Test func dividedByAFractionNeverOverflowsAnIntermediate() {
        let huge = Amount(baseUnits: pow10(37), asset: Fake.bedrock)
        #expect((huge / Fraction(percent: 50)).baseUnits == 2 * pow10(37))
        #expect((huge / Fraction(integer: 4)).baseUnits == 25 * pow10(35))
    }

    // MARK: Zero and sign

    // C3: zero(of:) is zero, of that asset
    @Test func zeroOfAnAssetIsZeroOfThatAsset() {
        let zero = Amount.zero(of: Fake.barney)
        #expect(zero.isZero)
        #expect(zero.baseUnits == 0)
        #expect(zero.asset == Fake.barney)
        #expect(zero == Amount(baseUnits: 0, asset: Fake.barney))
    }

    // C3: zero is not negative
    @Test func zeroIsNotNegative() {
        #expect(Amount.zero(of: Fake.fred).isNegative == false)
    }

    // C3: a positive amount is neither zero nor negative
    @Test func aPositiveAmountIsNeitherZeroNorNegative() {
        let amount = Amount(baseUnits: 1, asset: Fake.fred)
        #expect(amount.isZero == false)
        #expect(amount.isNegative == false)
    }

    // C3: a negative amount is negative and not zero
    @Test func aNegativeAmountIsNegative() {
        let amount = Amount(baseUnits: -1, asset: Fake.fred)
        #expect(amount.isNegative)
        #expect(amount.isZero == false)
    }

    // C3: zeros of two assets are not equal (== is total and the asset counts)
    @Test func zerosOfTwoAssetsAreNotEqual() {
        #expect(Amount.zero(of: Fake.fred) != Amount.zero(of: Fake.dino))
    }
}
