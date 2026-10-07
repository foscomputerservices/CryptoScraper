// C4 — A fraction: an exact ratio at a fixed scale.
// Projected from docs/fosline-suite-protocols.md C4 (not redesigned by the identity design):
// "A fraction is an integer numerator at a fixed scale, so it is exact to nine fraction digits and no further.
// From basis points, from a percent and from an integer it is exact; from two amounts it is a division and rounds
// toward zero at the scale."

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("C4 Fraction")
struct C4_FractionTests {
    // "From basis points, from a percent and from an integer it is exact"
    @Test func basisPointsPercentAndIntegerAgree() {
        #expect(Fraction(basisPoints: 100) == Fraction(percent: 1))
        #expect(Fraction(percent: 100) == Fraction(integer: 1))
        #expect(Fraction(integer: 1) == .one)
        #expect(Fraction(integer: 0) == .zero)
    }

    // "`Fraction(integer: 2) > Fraction(percent: 150)`"
    @Test func twoIsAboveOneHundredFiftyPercent() {
        #expect(Fraction(integer: 2) > Fraction(percent: 150))
    }

    // "`Fraction(amountOut - amountIn, over: amountIn)` on 112 over 100 is 12 percent"
    @Test func gainOfTwelvePercent() {
        let instance = AssetInstance.stub()
        let amountIn = Amount(baseUnits: 100, of: instance)
        let amountOut = Amount(baseUnits: 112, of: instance)
        #expect(Fraction(amountOut - amountIn, over: amountIn) == Fraction(percent: 12))
    }

    // "from two amounts it is a division and rounds toward zero at the scale"
    @Test func divisionRoundsTowardZero() {
        let instance = AssetInstance.stub()
        let third = Fraction(Amount(baseUnits: 1, of: instance), over: Amount(baseUnits: 3, of: instance))
        let twoThirds = Fraction(Amount(baseUnits: 2, of: instance), over: Amount(baseUnits: 3, of: instance))
        // 0.333333333 and 0.666666666 at nine digits: the sum falls short of 1 by one step
        #expect(third + twoThirds < .one)
        let negative = Fraction(Amount(baseUnits: -1, of: instance), over: Amount(baseUnits: 3, of: instance))
        #expect(negative + third == .zero)
    }

    // "`+` and `-` exist because T78's level reads as `.one - distance`"
    @Test func oneMinusDistance() {
        #expect(Fraction.one - Fraction(percent: 2) == Fraction(percent: 98))
        #expect(Fraction(percent: 2) + Fraction(percent: 98) == .one)
    }

    // "public var isZero", "public var isNegative"
    @Test func zeroAndNegative() {
        #expect(Fraction.zero.isZero)
        #expect(!Fraction.one.isZero)
        #expect((Fraction.zero - Fraction(percent: 1)).isNegative)
        #expect(!Fraction(percent: 1).isNegative)
    }

    // "Precondition: both amounts are of one asset" — across instances it traps
    @Test func overTwoInstancesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 1, of: .stub(address: "quarry-42")),
                         over: Amount(baseUnits: 2, of: .stub(address: "slate-42")))
        }
    }

    // "Precondition: ... `whole` is not zero"
    @Test func overZeroTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 1, of: .stub()), over: Amount.zero(of: .stub()))
        }
    }

    // "Encoding. `Amount`, `Fraction` and `Price` round-trip through `toJSON()` / `fromJSON()`"
    @Test func roundTrips() throws {
        let step = Fraction(basisPoints: 25)
        let back: Fraction = try step.toJSON().fromJSON()
        #expect(back == step)
    }
}
