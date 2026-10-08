import Testing
import Foundation
import CryptoAsset
import FOSMVVM
import CryptoAssetLocalization

@Suite("C10 LocalizableAmount: properties and conformances")
struct LocalizableAmountPropertiesTests {
    @Test("C10: the exact amount stays available as value")
    func valueIsTheExactAmount() {
        let amount = Fixture.amount(123_456, of: Fixture.dollar())
        #expect(LocalizableAmount(amount).value == amount)
    }

    @Test("C10: the unit is the asset's display unit unless one is given")
    func defaultUnitIsTheDisplayUnit() {
        let instance = Fixture.dollar()
        #expect(LocalizableAmount(Fixture.amount(1, of: instance)).unit == instance.displayUnit) // INVENTED: AssetInstance.displayUnit
    }

    @Test("C10: a unit that is given is the unit kept")
    func givenUnitIsKept() {
        let amount = LocalizableAmount(Fixture.amount(12_500, of: Fixture.eightDecimals()), in: Fixture.satoshi())
        #expect(amount.unit == Fixture.satoshi())
    }

    @Test("C10: fractionDigits defaults to the unit's own, 2 for the dollar unit")
    func defaultDigitsOfTheDollarUnit() {
        #expect(LocalizableAmount(Fixture.amount(1, of: Fixture.dollar())).fractionDigits == 2)
    }

    @Test("C10: fractionDigits defaults to the asset's exponent when the asset has no unit names")
    func defaultDigitsAreTheExponent() {
        #expect(LocalizableAmount(Fixture.amount(1, of: Fixture.eightDecimals())).fractionDigits == 8)
    }

    @Test("C10: the satoshi unit's default is no fraction digits")
    func defaultDigitsOfSatoshi() {
        #expect(LocalizableAmount(Fixture.amount(1, of: Fixture.eightDecimals()), in: Fixture.satoshi()).fractionDigits == 0)
    }

    @Test("C10: a given fractionDigits is kept")
    func givenDigitsAreKept() {
        #expect(LocalizableAmount(Fixture.amount(1, of: Fixture.eightDecimals()), fractionDigits: 2).fractionDigits == 2)
    }

    @Test("C10: fractionDigits is never more than the exponent")
    func digitsCappedAtTheExponent() {
        #expect(LocalizableAmount(Fixture.amount(1, of: Fixture.eightDecimals()), fractionDigits: 12).fractionDigits == 8)
    }

    @Test("C10: showsSymbol defaults to true and a given false is kept")
    func showsSymbolDefaultAndGiven() {
        let amount = Fixture.amount(1, of: Fixture.dollar())
        #expect(LocalizableAmount(amount).showsSymbol)
        #expect(!LocalizableAmount(amount, showsSymbol: false).showsSymbol)
    }

    @Test("C10: isEmpty is false, for zero as for any amount")
    func neverEmpty() {
        #expect(!LocalizableAmount(Fixture.amount(0, of: Fixture.dollar())).isEmpty)
        #expect(!LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar())).isEmpty)
    }

    @Test("C10: two amounts of the same value and unit are equal, hash alike and share an id")
    func equalWhenSame() {
        let a = LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar()))
        let b = LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar()))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a.id == b.id)
    }

    @Test("C10: the id follows the value's text and unit, so another amount or another unit has another id")
    func idFollowsValueAndUnit() {
        let instance = Fixture.eightDecimals()
        let base = LocalizableAmount(Fixture.amount(12_500, of: instance))
        #expect(base.id != LocalizableAmount(Fixture.amount(12_501, of: instance)).id)
        #expect(base.id != LocalizableAmount(Fixture.amount(12_500, of: instance), in: Fixture.satoshi()).id)
    }

    @Test("C10: Comparable orders amounts of one instance by their value")
    func comparableByValue() {
        let instance = Fixture.dollar()
        let small = LocalizableAmount(Fixture.amount(100, of: instance))
        let large = LocalizableAmount(Fixture.amount(200, of: instance))
        #expect(small < large)
        #expect(!(large < small))
        #expect(!(small < small))
        #expect([large, small].sorted() == [small, large])
    }

    @Test("C10: Comparable orders a negative amount before zero before a positive one")
    func comparableAcrossZero() {
        let instance = Fixture.dollar()
        let negative = LocalizableAmount(Fixture.amount(-1, of: instance))
        let zero = LocalizableAmount(Fixture.amount(0, of: instance))
        let positive = LocalizableAmount(Fixture.amount(1, of: instance))
        #expect([positive, zero, negative].sorted() == [negative, zero, positive])
    }
}
