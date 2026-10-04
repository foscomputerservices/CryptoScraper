// StubsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Stubs")
struct StubsTests {
    // The symbols a real exchange lists that this library knows: none may be a stub's.
    private let realSymbols: Set<String> = Set([Asset.usd, .usdc, .usdt, .btc, .eth].map(\.symbol.text))
    private let shippedExponents: Set<Int> = Set([Asset.usd, .usdc, .usdt, .btc, .eth].map(\.unitExponent))

    @Test func theAssetStubIsSelfMarking() {
        let stub = Asset.stub()
        #expect(stub.symbol.text == "FRED")
        #expect(stub.unitExponent == 4)
        #expect(!realSymbols.contains(stub.symbol.text))
        #expect(!shippedExponents.contains(stub.unitExponent))
    }

    @Test func theSymbolStubIsSelfMarking() {
        #expect(AssetSymbol.stub().text == "FRED")
        #expect(!realSymbols.contains(AssetSymbol.stub().text))
    }

    @Test func theAmountStubIs42() {
        let stub = Amount.stub()
        #expect(stub.baseUnits == 42)
        #expect(stub.asset == Asset.stub())
    }

    @Test func theFractionStubIs42Percent() {
        #expect(Fraction.stub() == Fraction(percent: 42))
    }

    @Test func thePriceStubIs42AndNeverOneAsset() {
        let stub = Price.stub()
        #expect(stub.cost(of: Amount(whole: 1, of: stub.base)) == Amount(whole: 42, of: stub.quote))
        #expect(stub.quote != stub.base)
        #expect(!realSymbols.contains(stub.quote.symbol.text))
        #expect(!realSymbols.contains(stub.base.symbol.text))
    }

    @Test func theBarIntervalStubIs42() {
        #expect(BarInterval.stub().count == 42)
    }

    @Test func theUnitStubsExponentIsOneNoShippedAssetUses() {
        let shipped = Set([Asset.usd, .usdc, .usdt, .btc, .eth].flatMap { asset in
            [asset.unitExponent] + asset.units.map(\.exponent)
        })
        #expect(!shipped.contains(Asset.Unit.stub().exponent))
        #expect(Asset.Unit.stub().exponent <= Asset.stub().unitExponent)
    }

    @Test func theUnitStubsAreFakes() {
        #expect(Asset.Unit.stub().name == "pebble")
        #expect(Asset.UnitDescription.stub().name == "pebble")
    }

    @Test func oneOverrideKeepsEveryOtherPieceAtItsFake() {
        let stub = Asset.stub()
        let eightPlaces = Asset.stub(unitExponent: 8)
        #expect(eightPlaces.unitExponent == 8)
        #expect(eightPlaces.symbol == stub.symbol)
        #expect(eightPlaces.wholeUnit.name == stub.wholeUnit.name)
        #expect(eightPlaces.wholeUnit.exponent == 8)
        #expect(eightPlaces.baseUnit == stub.baseUnit)
        #expect(eightPlaces.between == stub.between)
        #expect(eightPlaces.displayUnit.name == stub.displayUnit.name)

        let other = Amount.stub(baseUnits: 7)
        #expect(other.baseUnits == 7)
        #expect(other.asset == Amount.stub().asset)
    }
}
