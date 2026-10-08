// LocalizationStubsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoAssetLocalization
import FOSFoundation
import FOSMVVM
import Foundation
import Testing

// Each type's stub needs no registry and arrives localized, as FOSMVVM's own LocalizableInt's does.
@Suite("Stubs")
struct LocalizationStubsTests {
    @Test func theAmountsStub() throws {
        let stub = LocalizableAmount.stub()
        #expect(stub.value == .stub())
        #expect(stub.unit == .stub())
        #expect(stub.fractionDigits == 3)
        #expect(stub.showsSymbol)
        #expect(stub.localizationStatus == .localized)
        #expect(try stub.localizedString == "0.042 pebble")
        #expect(try LocalizableAmount.stub(showsSymbol: false).localizedString == "0.042")
        #expect(try LocalizableAmount.stub(value: .stub(baseUnits: 123_456), fractionDigits: 1).localizedString == "123.4 pebble")
    }

    @Test func thePricesStub() throws {
        let stub = LocalizablePrice.stub()
        #expect(stub.value == .stub())
        #expect(stub.fractionDigits == 2)
        #expect(try stub.localizedString == "42.00 FRED / FRED")
    }

    @Test func theFractionsStub() throws {
        let stub = LocalizableFraction.stub()
        #expect(stub.value == .stub())
        #expect(try stub.localizedString == "42.00 %")
        #expect(try LocalizableFraction.stub(showsSign: true).localizedString.hasSuffix("42.00 %"))
    }
}
