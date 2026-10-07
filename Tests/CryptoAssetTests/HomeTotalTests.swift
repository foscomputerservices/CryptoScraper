// HomeTotalTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// The owner's answer of 2026-10-06, "Home" (design § 7.3, road A): a total across exchanges counts in the asset's
// home instance; each side converts to it through the map with `converted(to:)`, and the total refuses where a
// digit would be lost. No member is declared for it.

@Suite("A total across exchanges counts in the home instance")
struct HomeTotalTests {
    @Test func aKrakenDollarAndACoinbaseDollarTotalInISO4217USD() throws {
        let registry = Fixtures.registryWithHoldings()
        let kraken = Amount(baseUnits: 11_013_400, of: Fixtures.krakenUSD)               // 1101.3400 at 4
        let coinbase = Amount(baseUnits: 2_510, of: Fixtures.coinbaseUSD)                // 25.10 at 2
        // Two values just arrived from two exchanges meet at the boundary, through the throwing pair.
        let total = try kraken.converted(to: Fixtures.usd, in: registry)
            .adding(coinbase.converted(to: Fixtures.usd, in: registry))
        #expect(total == Amount(baseUnits: 112_644, of: Fixtures.usd))                   // 1126.44
        #expect(try registry.asset(of: total.instance) == .usd)
    }

    @Test(arguments: [11_013_410, 11_013_401, 11_013_425] as [Int128])
    func aKrakenBalanceWithADigitInItsThirdOrFourthPlaceIsRefused(baseUnits: Int128) {
        let registry = Fixtures.registryWithHoldings()
        let kraken = Amount(baseUnits: baseUnits, of: Fixtures.krakenUSD)                // 1101.341, 1101.3401, 1101.3425
        #expect(throws: AmountError.notRepresentable(kraken, in: Fixtures.usd)) {
            try kraken.converted(to: Fixtures.usd, in: registry)
        }
    }

    @Test func theHomeIsTheAssetsOwnId() throws {
        let registry = Fixtures.registryWithHoldings()
        let home = try AssetInstance(validating: registry.asset(of: Fixtures.krakenUSD).id)
        #expect(home == Fixtures.usd)
        #expect(try registry.decimals(of: home) == 2)
    }
}
