// C2_Asset.swift
//
// C2: an asset, what a quantity is counted in, with its unit exponent and its units, never without a unit.
// R8, R9.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Asset — C2, R8, R9 behavioral")
struct C2_AssetTests {

    // MARK: The unit exponent, 0 through 30

    // C2: unitExponent "0 through 30": 0 is accepted
    @Test func anExponentOfZeroIsAccepted() throws {
        let asset = try Asset(symbol: "DINO", unitExponent: 0)
        #expect(asset.unitExponent == 0)
    }

    // C2: unitExponent "0 through 30": 30 is accepted
    @Test func anExponentOfThirtyIsAccepted() throws {
        let asset = try Asset(symbol: "BEDROCK", unitExponent: 30)
        #expect(asset.unitExponent == 30)
    }

    // C2: "Throws unitExponentOutOfRange outside 0 through 30": below
    @Test func aNegativeExponentIsOutOfRange() {
        #expect(throws: AssetError.unitExponentOutOfRange(-1)) {
            try Asset(symbol: "FRED", unitExponent: -1)
        }
    }

    // C2: "Throws unitExponentOutOfRange outside 0 through 30": above
    @Test func anExponentOfThirtyOneIsOutOfRange() {
        #expect(throws: AssetError.unitExponentOutOfRange(31)) {
            try Asset(symbol: "FRED", unitExponent: 31)
        }
    }

    // C2: out of range through the typed-symbol initializer too
    @Test func anExponentOutOfRangeIsRejectedThroughTheTypedSymbol() throws {
        let symbol = try AssetSymbol(validating: "FRED")
        #expect(throws: AssetError.unitExponentOutOfRange(42)) {
            try Asset(symbol: symbol, unitExponent: 42)
        }
    }

    // MARK: The string initializer validates the symbol

    // C2: "Validates the symbol too": an empty symbol is refused
    @Test func theStringInitializerRefusesAnEmptySymbol() {
        #expect(throws: AssetSymbolError.empty) {
            try Asset(symbol: "", unitExponent: 4)
        }
    }

    // C2: "Validates the symbol too": a malformed symbol is refused
    @Test func theStringInitializerRefusesAMalformedSymbol() {
        let error = #expect(throws: AssetSymbolError.self) {
            try Asset(symbol: "FRED FLINTSTONE", unitExponent: 4)
        }
        #expect(isMalformed(error))
    }

    // C2: the string and the typed-symbol initializers make one asset
    @Test func theStringAndTypedInitializersAgree() throws {
        let fromString = try Asset(symbol: "fred", unitExponent: 4)
        let fromSymbol = try Asset(symbol: AssetSymbol(validating: "FRED"), unitExponent: 4)
        #expect(fromString == fromSymbol)
        #expect(fromString.symbol.text == "FRED")
    }

    // MARK: Never without a unit

    // C2: "Every asset has a whole unit, named by its symbol unless it carries a name of its own"
    @Test func theWholeUnitIsNamedByTheSymbolWhenNoNameIsGiven() {
        #expect(Fake.fred.wholeUnit.name == "FRED")
    }

    // C2: the whole unit's exponent is the asset's
    @Test func theWholeUnitsExponentIsTheAssets() {
        #expect(Fake.fred.wholeUnit.exponent == 4)
        #expect(Fake.slate.wholeUnit.exponent == 18)
    }

    // C2: Unit.symbol is "nil for the asset's symbol" when no sign is given
    @Test func theWholeUnitHasNoSignWhenNoneIsGiven() {
        #expect(Fake.fred.wholeUnit.symbol == nil)
    }

    // C2: the whole unit carries the name, sign and fraction digits it was declared with
    @Test func theWholeUnitCarriesItsDescription() {
        let whole = Fake.barney.wholeUnit
        #expect(whole.name == "barney")
        #expect(whole.symbol == "Ƀ")
        #expect(whole.fractionDigits == 8)
        #expect(whole.exponent == 8)
    }

    // C2: "The base unit, where it has a name; nil for an asset whose smallest unit nobody names"
    @Test func theBaseUnitIsAbsentWhenNotNamed() {
        #expect(Fake.fred.baseUnit == nil)
    }

    // C2: a named base unit is exponent 0 (R9: "a unit ladder whose base is exponent 0")
    @Test func aNamedBaseUnitIsAtExponentZero() throws {
        let base = try #require(Fake.barney.baseUnit)
        #expect(base.name == "rubble")
        #expect(base.exponent == 0)
    }

    // C2: "Units named between the base and the whole, each at its exponent above the base"
    @Test func unitsBetweenAreKept() {
        #expect(Fake.slate.between == [Fake.pebble])
        #expect(Fake.fred.between.isEmpty)
    }

    // C2: "The unit a reader sees by default: the whole unit unless the asset says otherwise"
    @Test func theDisplayUnitDefaultsToTheWholeUnit() {
        #expect(Fake.fred.displayUnit == Fake.fred.wholeUnit)
        #expect(Fake.slate.displayUnit == Fake.slate.wholeUnit)
    }

    // C2: the display unit the asset says otherwise
    @Test func aDeclaredDisplayUnitIsKept() throws {
        let asset = try Asset(symbol: "SLATE", unitExponent: 18,
                              wholeUnit: .init(name: "slate"),
                              baseUnit: .init(name: "gravel"),
                              between: [Fake.pebble],
                              displayUnit: Fake.pebble)
        #expect(asset.displayUnit == Fake.pebble)
    }

    // C2: "so units is never empty": an asset with no names still has its whole unit
    @Test func unitsIsNeverEmpty() {
        #expect(Fake.fred.units.count == 1)
        #expect(Fake.fred.units.first == Fake.fred.wholeUnit)
        #expect(Fake.dino.units.isEmpty == false)
    }

    // C2: "Every unit a reader may count in: the base unit if named, those between, and the whole unit"
    // UNRATIFIED-CLARIFICATION: the sentence's order is read as the array's order (base, between, whole).
    @Test func unitsAreTheBaseThenThoseBetweenThenTheWhole() {
        #expect(Fake.slate.units.map(\.name) == ["gravel", "pebble", "slate"])
        #expect(Fake.slate.units.map(\.exponent) == [0, 9, 18])
    }

    // C2: an unnamed base unit is not among the units
    @Test func anUnnamedBaseUnitIsNotAmongTheUnits() {
        #expect(Fake.fred.units.allSatisfy { $0.exponent != 0 })
    }

    // C2: "The unit named name, or nil"
    @Test func aUnitIsFoundByItsName() throws {
        #expect(Fake.slate.unit(named: "pebble") == Fake.pebble)
        #expect(Fake.slate.unit(named: "gravel")?.exponent == 0)
        #expect(Fake.slate.unit(named: "slate")?.exponent == 18)
    }

    // C2: the whole unit named by the symbol is found by the symbol
    @Test func anUnnamedWholeUnitIsFoundByTheSymbol() {
        #expect(Fake.fred.unit(named: "FRED") == Fake.fred.wholeUnit)
    }

    // C2: "or nil"
    @Test func anUnknownUnitNameIsNil() {
        #expect(Fake.slate.unit(named: "boulder") == nil)
    }

    // MARK: A unit's exponent lies between 0 and the asset's

    // C2: "unitOutOfRange when a unit's exponent is not between 0 and the asset's": above
    @Test func aUnitBetweenAboveTheAssetsExponentIsOutOfRange() {
        let boulder = Asset.Unit(name: "boulder", exponent: 19)
        #expect(throws: AssetError.unitOutOfRange(boulder)) {
            try Asset(symbol: "SLATE", unitExponent: 18, between: [boulder])
        }
    }

    // C2: "unitOutOfRange when a unit's exponent is not between 0 and the asset's": below
    @Test func aUnitBetweenBelowZeroIsOutOfRange() {
        let grain = Asset.Unit(name: "grain", exponent: -1)
        #expect(throws: AssetError.unitOutOfRange(grain)) {
            try Asset(symbol: "SLATE", unitExponent: 18, between: [grain])
        }
    }

    // C2: a display unit outside the asset's range is out of range
    @Test func aDisplayUnitAboveTheAssetsExponentIsOutOfRange() {
        let boulder = Asset.Unit(name: "boulder", exponent: 19)
        #expect(throws: AssetError.unitOutOfRange(boulder)) {
            try Asset(symbol: "SLATE", unitExponent: 18, displayUnit: boulder)
        }
    }

    // C2: a unit inside the range passes
    @Test func aUnitBetweenInsideTheRangeIsAccepted() throws {
        let asset = try Asset(symbol: "SLATE", unitExponent: 18, between: [Fake.pebble])
        #expect(asset.between == [Fake.pebble])
    }

    // MARK: Identity is the symbol and the exponent

    // C2: "Two assets are the same asset when their symbol and exponent are the same; the units are a
    // description and never part of the identity"
    @Test func assetsWithTheSameSymbolAndExponentButDifferentUnitsAreEqual() {
        #expect(Fake.fred == Fake.fredNamed)
    }

    // C2: identity is the symbol and the exponent, so the hash agrees
    @Test func assetsWithTheSameSymbolAndExponentHashAlike() {
        #expect(Set([Fake.fred, Fake.fredNamed]).count == 1)
        #expect(Fake.fred.hashValue == Fake.fredNamed.hashValue)
    }

    // C2: a different exponent is a different asset
    @Test func assetsWithTheSameSymbolButDifferentExponentsAreNotEqual() {
        #expect(Fake.fred != Fake.fredAtEight)
    }

    // C2: a different symbol is a different asset
    @Test func assetsWithDifferentSymbolsAndTheSameExponentAreNotEqual() throws {
        let wilma = try Asset(symbol: "WILMA", unitExponent: 4)
        #expect(Fake.fred != wilma)
    }

    // C2: a named unit carries what it was made with
    @Test func aUnitCarriesItsNameExponentSignAndDigits() {
        let unit = Asset.Unit(name: "pebble", exponent: 9, symbol: "ᵽ", fractionDigits: 2)
        #expect(unit.name == "pebble")
        #expect(unit.exponent == 9)
        #expect(unit.symbol == "ᵽ")
        #expect(unit.fractionDigits == 2)
    }

    // C2: a unit with no sign and no digits says nil for both ("nil for all of them")
    @Test func aUnitWithNoSignOrDigitsSaysNil() {
        #expect(Fake.pebble.symbol == nil)
        #expect(Fake.pebble.fractionDigits == nil)
    }

    // C2: a unit description carries what it was made with
    @Test func aUnitDescriptionCarriesItsNameSignAndDigits() {
        let description = Asset.UnitDescription(name: "fred", symbol: "₣", fractionDigits: 4)
        #expect(description.name == "fred")
        #expect(description.symbol == "₣")
        #expect(description.fractionDigits == 4)
    }
}
