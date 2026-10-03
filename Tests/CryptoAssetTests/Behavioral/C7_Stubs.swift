// C7_Stubs.swift
//
// C7: the stubs of § 1's values in the two-stub form: stub(), and stub(…) with every property of the
// designated initializer as an optional parameter defaulting to the reserved fake. R11: stubs in FOS's
// reserved-fake vocabulary (values at or near ±42, Flintstones names).
// Only Asset's parameterized stub is declared; the others' parameterized forms are named but not declared,
// so only their stub() is called here.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Stubs — C7, R11 behavioral")
struct C7_StubsTests {

    // MARK: Asset

    // C7: "The reserved-fake asset for a test that does not care which: FRED at exponent 4"
    @Test func theAssetStubIsFREDAtExponentFour() {
        let stub = Asset.stub()
        #expect(stub.symbol.text == "FRED")
        #expect(stub.unitExponent == 4)
        #expect(stub == Fake.fred)
    }

    // C7: stub(unitExponent:) overrides only the exponent
    @Test func theAssetStubOverridesTheExponentAlone() {
        let stub = Asset.stub(unitExponent: 8)
        #expect(stub.unitExponent == 8)
        #expect(stub.symbol.text == "FRED")
    }

    // C7: stub(symbol:) overrides only the symbol
    @Test func theAssetStubOverridesTheSymbolAlone() throws {
        let stub = Asset.stub(symbol: try AssetSymbol(validating: "BARNEY"))
        #expect(stub.symbol.text == "BARNEY")
        #expect(stub.unitExponent == 4)
    }

    // C7: stub(wholeUnit:) overrides the whole unit's description
    @Test func theAssetStubOverridesTheWholeUnit() {
        let stub = Asset.stub(wholeUnit: .init(name: "fred", symbol: "₣"))
        #expect(stub.wholeUnit.name == "fred")
        #expect(stub.wholeUnit.symbol == "₣")
        #expect(stub.wholeUnit.exponent == 4)
    }

    // C7: stub(baseUnit:) overrides the base unit's description
    @Test func theAssetStubOverridesTheBaseUnit() {
        let stub = Asset.stub(baseUnit: .init(name: "flintstone"))
        #expect(stub.baseUnit?.name == "flintstone")
        #expect(stub.baseUnit?.exponent == 0)
    }

    // C7: stub(between:displayUnit:) overrides the units between and the display unit
    @Test func theAssetStubOverridesBetweenAndDisplayUnit() {
        let pebble = Asset.Unit(name: "pebble", exponent: 2)
        let stub = Asset.stub(between: [pebble], displayUnit: pebble)
        #expect(stub.between == [pebble])
        #expect(stub.displayUnit == pebble)
    }

    // C7: the stub makes a value without throwing, usable as any other asset
    @Test func theAssetStubCountsLikeAnyAsset() {
        #expect(Amount(whole: 42, of: .stub()).baseUnits == 420_000)
    }

    // MARK: Amount

    // C3, R11: "the 42 in its stub"
    @Test func theAmountStubIsFortyTwoBaseUnits() {
        #expect(Amount.stub().baseUnits == 42)
    }

    // MARK: Every stub is a valid, self-consistent value

    // C1, R11: the symbol stub passes its own validation
    @Test func theSymbolStubIsAValidSymbol() throws {
        let stub = AssetSymbol.stub()
        #expect(try AssetSymbol(validating: stub.text) == stub)
    }

    // R11: "Flintstones names"
    // UNRATIFIED-CLARIFICATION: the symbol stub's text is not stated; R11's vocabulary is read as a Flintstones name.
    @Test func theSymbolStubIsAFlintstonesName() {
        let flintstones: Set<String> = ["FRED", "WILMA", "PEBBLES", "BARNEY", "BETTY", "BAMM-BAMM", "DINO", "SLATE", "GAZOO"]
        #expect(flintstones.contains(AssetSymbol.stub().text))
    }

    // C7: every stub survives a JSON round trip
    @Test func everyStubRoundTrips() throws {
        #expect(try roundTrip(AssetSymbol.stub()) == AssetSymbol.stub())
        #expect(try roundTrip(Asset.stub()) == Asset.stub())
        #expect(try roundTrip(Asset.Unit.stub()) == Asset.Unit.stub())
        #expect(try roundTrip(Asset.UnitDescription.stub()) == Asset.UnitDescription.stub())
        #expect(try roundTrip(Amount.stub()) == Amount.stub())
        #expect(try roundTrip(Fraction.stub()) == Fraction.stub())
        #expect(try roundTrip(Price.stub()) == Price.stub())
        #expect(try roundTrip(BarInterval.stub()) == BarInterval.stub())
    }

    // C7: a stub is stable: two calls give one value
    @Test func stubsAreStable() {
        #expect(AssetSymbol.stub() == AssetSymbol.stub())
        #expect(Asset.stub() == Asset.stub())
        #expect(Amount.stub() == Amount.stub())
        #expect(Fraction.stub() == Fraction.stub())
        #expect(Price.stub() == Price.stub())
        #expect(BarInterval.stub() == BarInterval.stub())
    }

    // C7: the unit stub lies inside the stub asset's range, so it can be declared on it
    // UNRATIFIED-CLARIFICATION: nothing ties Asset.Unit.stub() to Asset.stub(); a usable pairing is read as intended.
    @Test func theUnitStubFitsTheAssetStub() throws {
        let unit = Asset.Unit.stub()
        #expect(unit.exponent >= 0)
        #expect(unit.exponent <= Asset.stub().unitExponent)
    }

    // C7: the price stub's cost can be taken of its own base
    @Test func thePriceStubCostsItsOwnBase() {
        let price = Price.stub()
        #expect(price.cost(of: .zero(of: price.base)).isZero)
        #expect(price.cost(of: .zero(of: price.base)).asset == price.quote)
    }
}
