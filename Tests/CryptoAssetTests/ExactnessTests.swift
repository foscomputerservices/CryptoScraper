// ExactnessTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Exactness")
struct ExactnessTests {
    @Test func wholeUnitsAreExact() throws {
        #expect(try Amount(whole: 100, of: Fixtures.usdc, in: Fixtures.registry()).baseUnits == 100_000_000)
    }

    @Test func additionIsExactAtTheTop() {
        let nearTop = Amount(baseUnits: .max - 1, of: Fixtures.eth)
        let one = Amount(baseUnits: 1, of: Fixtures.eth)
        #expect((nearTop + one).baseUnits == Int128.max)
        #expect((Amount(baseUnits: .max, of: Fixtures.eth) - one).baseUnits == Int128.max - 1)
    }

    @Test func subtractionIsExactAtTheBottom() {
        let nearBottom = Amount(baseUnits: .min + 1, of: Fixtures.eth)
        let one = Amount(baseUnits: 1, of: Fixtures.eth)
        #expect((nearBottom - one).baseUnits == Int128.min)
        #expect((Amount(baseUnits: .min, of: Fixtures.eth) + one).baseUnits == Int128.min + 1)
    }

    @Test func addingTwoInstancesThrowsInstanceConflict() throws {
        let registry = Fixtures.registry()
        let dollars = try Amount(whole: 1, of: Fixtures.usd, in: registry)
        let bitcoin = try Amount(whole: 1, of: Fixtures.btc, in: registry)
        #expect(throws: AmountError.instanceConflict(Fixtures.usd, Fixtures.btc)) {
            try dollars.adding(bitcoin)
        }
    }

    @Test func aNamedUnitRoundTripsAsACount() throws {
        let registry = Fixtures.registry()
        let amount = try Amount(count: 12_500, in: Fixtures.satoshi, of: Fixtures.btc, in: registry)
        let read = try amount.count(in: Fixtures.satoshi, in: registry)
        #expect(read.count == 12_500)
        #expect(read.remainder == 0)
    }
}
