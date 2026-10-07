// StubsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Stubs")
struct StubsTests {
    // The symbols a real exchange lists that this library knows: none may be a stub's.
    private let realSymbols: Set<String> = Set(AssetRegistry.libraryDeclarations.map(\.symbol.text))
    // Every decimals from 0 through 18 ships since the top-1000 run of 2026-10-07, so a stub marks itself by its
    // instance id, never by its decimals
    private let shippedInstanceIds: Set<String> = Set(AssetRegistry.libraryDeclarations.flatMap { $0.instances.map(\.instance.id) })

    @Test func theAssetStubIsSelfMarking() {
        let stub = Asset.stub()
        #expect(stub.id == "bedrock:42:quarry-42")
        #expect(stub.id == AssetInstance.stub().id)
        #expect(Asset.stub(home: .stub(address: "boulder-42")).id == "bedrock:42:boulder-42")
    }

    @Test func theDeclarationStubIsSelfMarking() {
        let stub = AssetDeclaration.stub()
        #expect(stub.asset == Asset.stub())
        #expect(stub.symbol.text == "FRED")
        #expect(stub.instances == [AssetDeclaration.Instance.stub()])
        #expect(!realSymbols.contains(stub.symbol.text))
        #expect(!shippedInstanceIds.contains(AssetDeclaration.Instance.stub().instance.id))
        #expect(AssetDeclaration.Instance.stub().instance == AssetInstance.stub())
    }

    @Test func theSymbolStubIsSelfMarking() {
        #expect(AssetSymbol.stub().text == "FRED")
        #expect(!realSymbols.contains(AssetSymbol.stub().text))
    }

    @Test func theAmountStubIs42() {
        let stub = Amount.stub()
        #expect(stub.baseUnits == 42)
        #expect(stub.instance == AssetInstance.stub())
    }

    @Test func theFractionStubIs42Percent() {
        #expect(Fraction.stub() == Fraction(percent: 42))
    }

    @Test func thePriceStubIs42AndNeverOneInstance() throws {
        let stub = Price.stub()
        let registry = try AssetRegistry([
            .stub(),
            .stub(asset: .stub(home: stub.base), instances: [.stub(instance: stub.base)])
        ])
        // 42 quote base units per whole base unit: one whole base at the stub's 4 decimals
        #expect(try stub.cost(of: Amount(baseUnits: 10_000, of: stub.base), in: registry) == Amount(baseUnits: 42, of: stub.quote))
        #expect(stub.quote != stub.base)
    }

    @Test func theBarIntervalStubIs42() {
        #expect(BarInterval.stub().count == 42)
    }

    @Test func theUnitStubsExponentIsOneNoShippedAssetUses() {
        let shipped = Set(AssetRegistry.libraryDeclarations.flatMap { declaration in
            declaration.instances.map(\.decimals) + declaration.units.map(\.exponent)
        })
        #expect(!shipped.contains(Asset.Unit.stub().exponent))
        #expect(Asset.Unit.stub().exponent <= AssetDeclaration.Instance.stub().decimals)
    }

    @Test func theUnitStubsAreFakes() {
        #expect(Asset.Unit.stub().name == "pebble")
        #expect(Asset.UnitDescription.stub().name == "pebble")
    }

    @Test func oneOverrideKeepsEveryOtherPieceAtItsFake() {
        let stub = AssetDeclaration.stub()
        let eightPlaces = AssetDeclaration.stub(instances: [.stub(decimals: 8)])
        #expect(eightPlaces.instances.map(\.decimals) == [8])
        #expect(eightPlaces.symbol == stub.symbol)
        #expect(eightPlaces.wholeUnit.name == stub.wholeUnit.name)
        #expect(eightPlaces.wholeUnit.exponent == 8)
        #expect(eightPlaces.baseUnit == stub.baseUnit)
        #expect(eightPlaces.between == stub.between)
        #expect(eightPlaces.displayUnit.name == stub.displayUnit.name)
        let other = Amount.stub(baseUnits: 7)
        #expect(other.baseUnits == 7)
        #expect(other.instance == Amount.stub().instance)
    }
}
