// NamedUnitsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("The named units, both ways")
struct NamedUnitsTests {
    @Test func gweiIntoBaseUnits() throws {
        let tip = try Amount(count: 5, in: Fixtures.gwei, of: Fixtures.eth, in: Fixtures.registry())
        #expect(tip.baseUnits == 5_000_000_000)
        #expect(try tip.count(in: Fixtures.gwei, in: Fixtures.registry()) == (count: 5, remainder: 0))
    }

    @Test func aQuantityNotWholeInTheUnitReturnsTheRemainder() throws {
        let amount = Amount(baseUnits: 5_000_000_123, of: Fixtures.eth)
        #expect(try amount.count(in: Fixtures.gwei, in: Fixtures.registry()) == (count: 5, remainder: 123))
        #expect(try amount.count(in: Fixtures.wei, in: Fixtures.registry()) == (count: 5_000_000_123, remainder: 0))
        #expect(try amount.count(in: Fixtures.ether, in: Fixtures.registry()) == (count: 0, remainder: 5_000_000_123))
    }

    @Test func aNegativeQuantityReadsTowardZero() throws {
        let amount = Amount(baseUnits: -5_000_000_123, of: Fixtures.eth)
        #expect(try amount.count(in: Fixtures.gwei, in: Fixtures.registry()) == (count: -5, remainder: -123))
    }

    @Test func dollarsAndCents() throws {
        let amount = try Amount(count: 1_234_56, in: Fixtures.cent, of: Fixtures.usd, in: Fixtures.registry())
        #expect(try amount.count(in: Fixtures.dollar, in: Fixtures.registry()) == (count: 1_234, remainder: 56))
        #expect(try Amount(count: 3, in: Fixtures.dollar, of: Fixtures.usd, in: Fixtures.registry()).baseUnits == 300)
    }

    @Test func aUnitNotTheAssetsThrowsUnitOutOfRange() throws {
        #expect(throws: AssetError.unitOutOfRange(Fixtures.satoshi)) {
            try Amount(count: 1, in: Fixtures.satoshi, of: Fixtures.eth, in: Fixtures.registry())
        }
    }
}
