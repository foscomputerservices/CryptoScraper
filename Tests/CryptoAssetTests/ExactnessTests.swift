// ExactnessTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Exactness")
struct ExactnessTests {
    @Test func wholeUnitsAreExact() {
        #expect(Amount(whole: 100, of: .usdc).baseUnits == 100_000_000)
    }

    @Test func additionIsExactAtTheTop() {
        let nearTop = Amount(baseUnits: .max - 1, asset: .eth)
        let one = Amount(baseUnits: 1, asset: .eth)
        #expect((nearTop + one).baseUnits == Int128.max)
        #expect((Amount(baseUnits: .max, asset: .eth) - one).baseUnits == Int128.max - 1)
    }

    @Test func subtractionIsExactAtTheBottom() {
        let nearBottom = Amount(baseUnits: .min + 1, asset: .eth)
        let one = Amount(baseUnits: 1, asset: .eth)
        #expect((nearBottom - one).baseUnits == Int128.min)
        #expect((Amount(baseUnits: .min, asset: .eth) + one).baseUnits == Int128.min + 1)
    }

    @Test func addingTwoAssetsThrowsAssetConflict() {
        let dollars = Amount(whole: 1, of: .usd)
        let bitcoin = Amount(whole: 1, of: .btc)
        #expect(throws: AmountError.assetConflict(Asset.usd.symbol, Asset.btc.symbol)) {
            try dollars.adding(bitcoin)
        }
    }

    @Test func aNamedUnitRoundTripsAsACount() throws {
        let amount = try Amount(count: 12_500, in: Fixtures.satoshi, of: .btc)
        let read = amount.count(in: Fixtures.satoshi)
        #expect(read.count == 12_500)
        #expect(read.remainder == 0)
    }
}
