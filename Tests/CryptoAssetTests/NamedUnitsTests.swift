// NamedUnitsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("The named units, both ways")
struct NamedUnitsTests {
    @Test func gweiIntoBaseUnits() throws {
        let tip = try Amount(count: 5, in: Fixtures.gwei, of: .eth)
        #expect(tip.baseUnits == 5_000_000_000)
        #expect(tip.count(in: Fixtures.gwei) == (count: 5, remainder: 0))
    }

    @Test func aQuantityNotWholeInTheUnitReturnsTheRemainder() {
        let amount = Amount(baseUnits: 5_000_000_123, asset: .eth)
        #expect(amount.count(in: Fixtures.gwei) == (count: 5, remainder: 123))
        #expect(amount.count(in: Fixtures.wei) == (count: 5_000_000_123, remainder: 0))
        #expect(amount.count(in: Fixtures.ether) == (count: 0, remainder: 5_000_000_123))
    }

    @Test func aNegativeQuantityReadsTowardZero() {
        let amount = Amount(baseUnits: -5_000_000_123, asset: .eth)
        #expect(amount.count(in: Fixtures.gwei) == (count: -5, remainder: -123))
    }

    @Test func dollarsAndCents() throws {
        let amount = try Amount(count: 1_234_56, in: Fixtures.cent, of: .usd)
        #expect(amount.count(in: Fixtures.dollar) == (count: 1_234, remainder: 56))
        #expect(try Amount(count: 3, in: Fixtures.dollar, of: .usd).baseUnits == 300)
    }

    @Test func aUnitNotTheAssetsThrowsUnitOutOfRange() {
        #expect(throws: AssetError.unitOutOfRange(Fixtures.satoshi)) {
            try Amount(count: 1, in: Fixtures.satoshi, of: .eth)
        }
    }
}
