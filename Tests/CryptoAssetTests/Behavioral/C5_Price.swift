// C5_Price.swift
//
// C5: a price, an amount of a quote asset per one whole unit of a base asset, held at a scale, with the cost
// it produces and the spread between two. R3: "price.cost(of: size)", a cost in the quote currency with the
// base's decimals divided out.
// Fixtures: FRED (exponent 4) is the quote, BARNEY (exponent 8) the base, DINO (exponent 0) a cheap token.
// The traps of its preconditions are in C6_BoundaryRule.swift.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Price — C5, R3 behavioral")
struct C5_PriceTests {

    /// 42 FRED per whole BARNEY
    static let mid = Price(Amount(whole: 42, of: Fake.fred), per: Fake.barney)

    // MARK: Its two assets

    // C5: "This much quote for one whole unit of base": the quote is the amount's asset, the base is given
    @Test func aPriceCarriesItsQuoteAndItsBase() {
        #expect(Self.mid.quote == Fake.fred)
        #expect(Self.mid.base == Fake.barney)
    }

    // C5: "The price a fill states": the base is the size's asset
    @Test func aFillPriceTakesItsBaseFromTheSize() {
        let fill = Price(Amount(whole: 84, of: Fake.fred), per: Amount(whole: 2, of: Fake.barney))
        #expect(fill.quote == Fake.fred)
        #expect(fill.base == Fake.barney)
    }

    // C5: a fill of 84 for 2 whole is the same price as 42 per one whole
    @Test func aFillPriceEqualsThePricePerOneWholeUnit() {
        let fill = Price(Amount(whole: 84, of: Fake.fred), per: Amount(whole: 2, of: Fake.barney))
        #expect(fill == Self.mid)
    }

    // C5: a fill for a fraction of a whole unit states the price per whole unit
    @Test func aFillForHalfAUnitStatesThePricePerWholeUnit() {
        let fill = Price(Amount(whole: 21, of: Fake.fred), per: Amount(baseUnits: 50_000_000, asset: Fake.barney))
        #expect(fill == Self.mid)
    }

    // MARK: The cost

    // C5: "The cost of size at this price, in the quote asset"
    @Test func theCostIsInTheQuoteAsset() {
        let cost = Self.mid.cost(of: Amount(baseUnits: 50_000_000, asset: Fake.barney))
        #expect(cost.asset == Fake.fred)
        #expect(cost == Amount(whole: 21, of: Fake.fred))
    }

    // C5, R3: the base's unit exponent is divided out: one whole unit costs the price
    @Test func theCostOfOneWholeUnitIsThePrice() {
        #expect(Self.mid.cost(of: Amount(whole: 1, of: Fake.barney)) == Amount(whole: 42, of: Fake.fred))
    }

    // C5: the cost of nothing is nothing
    @Test func theCostOfZeroIsZero() {
        #expect(Self.mid.cost(of: .zero(of: Fake.barney)).isZero)
    }

    // C5: "rounded toward zero": less than one quote base unit is zero
    @Test func theCostRoundsTowardZero() {
        let onePerWhole = Price(Amount(baseUnits: 1, asset: Fake.fred), per: Fake.barney)
        #expect(onePerWhole.cost(of: Amount(baseUnits: 99_999_999, asset: Fake.barney)).baseUnits == 0)
        #expect(onePerWhole.cost(of: Amount(baseUnits: 100_000_000, asset: Fake.barney)).baseUnits == 1)
        #expect(onePerWhole.cost(of: Amount(baseUnits: 250_000_000, asset: Fake.barney)).baseUnits == 2)
    }

    // C3, C5: "Rounding is toward zero everywhere, for a positive and a negative quantity alike"
    // UNRATIFIED-CLARIFICATION: cost(of:) states no precondition on the size's sign; a negative size is read
    // as allowed, giving a negative cost rounded toward zero.
    @Test func theCostOfANegativeSizeRoundsTowardZero() {
        let onePerWhole = Price(Amount(baseUnits: 1, asset: Fake.fred), per: Fake.barney)
        #expect(onePerWhole.cost(of: Amount(baseUnits: -150_000_000, asset: Fake.barney)).baseUnits == -1)
        #expect(Self.mid.cost(of: Amount(baseUnits: -50_000_000, asset: Fake.barney)) == Amount(whole: -21, of: Fake.fred))
    }

    // C5 with C2: a size of a named declaration of the base asset is the base asset
    @Test func theCostAcceptsANamedAndAnUnnamedDeclarationOfTheBase() throws {
        let barneyBare = try Asset(symbol: "BARNEY", unitExponent: 8)
        #expect(Self.mid.cost(of: Amount(whole: 1, of: barneyBare)) == Amount(whole: 42, of: Fake.fred))
    }

    // C5, R2: the cost is taken at full width
    @Test func theCostOfAHugeSizeIsExact() {
        let price = Price(Amount(whole: 42, of: Fake.dino), per: Fake.bedrock)
        let size = Amount(baseUnits: pow10(36), asset: Fake.bedrock)
        #expect(price.cost(of: size) == Amount(baseUnits: 42 * pow10(6), asset: Fake.dino))
    }

    // MARK: Below one quote base unit, exact

    // C5: "held at a scale, so a price below one quote base unit per whole base unit is exact": 0.4 each
    @Test func aSubUnitPriceIsNotZero() {
        let fill = Price(Amount(baseUnits: 4_000, asset: Fake.barney), per: Amount(whole: 10_000, of: Fake.dino))
        #expect(fill.isZero == false)
    }

    // C5: 0.4 base unit each, applied back to the fill's size, is the fill's amount
    @Test func aSubUnitPriceCostsTheFillsAmountBack() {
        let fill = Price(Amount(baseUnits: 4_000, asset: Fake.barney), per: Amount(whole: 10_000, of: Fake.dino))
        #expect(fill.cost(of: Amount(whole: 10_000, of: Fake.dino)) == Amount(baseUnits: 4_000, asset: Fake.barney))
        #expect(fill.cost(of: Amount(whole: 1_000_000, of: Fake.dino)) == Amount(baseUnits: 400_000, asset: Fake.barney))
    }

    // C5: 0.4 each, on small sizes, rounds toward zero
    @Test func aSubUnitPriceRoundsSmallCostsTowardZero() {
        let fill = Price(Amount(baseUnits: 4_000, asset: Fake.barney), per: Amount(whole: 10_000, of: Fake.dino))
        #expect(fill.cost(of: Amount(whole: 5, of: Fake.dino)).baseUnits == 2)
        #expect(fill.cost(of: Amount(whole: 3, of: Fake.dino)).baseUnits == 1)
        #expect(fill.cost(of: Amount(whole: 1, of: Fake.dino)).baseUnits == 0)
    }

    // C5: a sub-unit price stated per base asset is exact too
    @Test func aSubUnitPriceStatedPerAssetIsNotZero() {
        let halfPerWhole = Price(Amount(baseUnits: 1, asset: Fake.fred), per: Fake.barney) * Fraction(percent: 50)
        #expect(halfPerWhole.isZero == false)
        #expect(halfPerWhole.cost(of: Amount(whole: 2, of: Fake.barney)).baseUnits == 1)
    }

    // MARK: Walking the ladder

    // C5: "Walks a step of the ladder": one step of 5 basis points up
    @Test func aStepUpTheLadderRaisesThePrice() {
        let ask = Self.mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.cost(of: Amount(whole: 1, of: Fake.barney)) == Amount(baseUnits: 420_210, asset: Fake.fred))
        #expect(ask.quote == Fake.fred)
        #expect(ask.base == Fake.barney)
    }

    // C5: a step down
    @Test func aStepDownTheLadderLowersThePrice() {
        let bid = Self.mid * (.one - Fraction(basisPoints: 5))
        #expect(bid.cost(of: Amount(whole: 1, of: Fake.barney)) == Amount(baseUnits: 419_790, asset: Fake.fred))
    }

    // C5: times one is the same price
    @Test func timesOneIsTheSamePrice() {
        #expect(Self.mid * .one == Self.mid)
    }

    // C5: times zero is a zero price
    @Test func timesZeroIsAZeroPrice() {
        #expect((Self.mid * .zero).isZero)
    }

    // MARK: Ordering

    // C5: "So min and max order a ladder of candidate prices"
    @Test func aLowerPriceIsLess() {
        let ask = Self.mid * (.one + Fraction(basisPoints: 5))
        let bid = Self.mid * (.one - Fraction(basisPoints: 5))
        #expect(bid < Self.mid)
        #expect(Self.mid < ask)
        #expect((ask < bid) == false)
    }

    // C5: min and max over a ladder
    @Test func minAndMaxPickFromALadder() {
        let ladder = [
            Self.mid,
            Self.mid * (.one + Fraction(basisPoints: 5)),
            Self.mid * (.one - Fraction(basisPoints: 5)),
        ]
        #expect(ladder.max() == Self.mid * (.one + Fraction(basisPoints: 5)))
        #expect(ladder.min() == Self.mid * (.one - Fraction(basisPoints: 5)))
    }

    // MARK: The spread

    // C5: the spread from a price to itself is zero
    @Test func theSpreadToItselfIsZero() {
        #expect(Self.mid.spread(to: Self.mid).isZero)
    }

    // C5: "The spread from this price to other, in percentage points of this one"
    // Gap: the sign of the spread (other less this, or this less other) is not stated; its size is asserted.
    @Test func theSpreadIsInPercentagePointsOfThisPrice() {
        let ask = Self.mid * (.one + Fraction(basisPoints: 5))
        let spread = Self.mid.spread(to: ask)
        let fiveBasisPoints = Fraction(basisPoints: 5)
        #expect(spread == fiveBasisPoints || spread == .zero - fiveBasisPoints)
    }

    // C5: the spread is measured against this price, not the other: 1 to 2 is 100 %, 2 to 1 is 50 %
    @Test func theSpreadIsMeasuredAgainstThisPrice() {
        let one = Price(Amount(whole: 1, of: Fake.fred), per: Fake.barney)
        let two = Price(Amount(whole: 2, of: Fake.fred), per: Fake.barney)
        let up = one.spread(to: two)
        let down = two.spread(to: one)
        #expect(up == .one || up == .zero - .one)
        #expect(down == Fraction(percent: 50) || down == .zero - Fraction(percent: 50))
    }

    // C5: the spread's sign flips with the direction
    @Test func theSpreadsSignFlipsWithDirection() {
        let ask = Self.mid * (.one + Fraction(basisPoints: 5))
        let bid = Self.mid * (.one - Fraction(basisPoints: 5))
        #expect(Self.mid.spread(to: ask).isNegative != Self.mid.spread(to: bid).isNegative)
    }

    // MARK: Zero

    // C5: a price of zero quote is zero
    @Test func aPriceOfZeroIsZero() {
        #expect(Price(.zero(of: Fake.fred), per: Fake.barney).isZero)
        #expect(Self.mid.isZero == false)
    }

    // MARK: Identity

    // C5: prices with different bases are not equal
    // UNRATIFIED-CLARIFICATION: C3 says Amount's == is total; C5 does not say it of Price. Hashable is read as
    // requiring a total == here too (no trap).
    @Test func pricesWithDifferentBasesAreNotEqual() {
        #expect(Self.mid != Price(Amount(whole: 42, of: Fake.fred), per: Fake.slate))
    }

    // C5: prices with different quotes are not equal
    @Test func pricesWithDifferentQuotesAreNotEqual() {
        #expect(Self.mid != Price(Amount(whole: 42, of: Fake.dino), per: Fake.barney))
    }

    // R10: equal prices hash alike
    @Test func equalPricesHashAlike() {
        let fill = Price(Amount(whole: 84, of: Fake.fred), per: Amount(whole: 2, of: Fake.barney))
        #expect(Set([Self.mid, fill]).count == 1)
    }
}
