// StreamUnitOfAccountTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Testing

// Design § 6, "The stream's unit of account" (§ 3.3): a stream lives on one exchange chain and counts in its
// holdings, so its arithmetic stays within one instance and performs no lookup.

@Suite("The stream's unit of account")
struct StreamUnitOfAccountTests {
    @Test func aHyperliquidStakeIsOneHundredMillionBaseUnits() throws {
        let stake = try Amount(whole: 100, of: Fixtures.hyperliquidUSDC, in: Fixtures.registryWithHoldings())
        #expect(stake.baseUnits == 100_000_000)
        #expect(stake.instance == Fixtures.hyperliquidUSDC)
    }

    @Test func theArithmeticRunsAgainstARegistryThatThrowsOnEveryCall() throws {
        let throwing = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclaredInstance(Fixtures.hyperliquidUSDC)) {
            try throwing.decimals(of: Fixtures.hyperliquidUSDC)
        }

        // The postings of a stream: every one in Hyperliquid's instances, every operation pure.
        let stake = Amount(baseUnits: 100_000_000, of: Fixtures.hyperliquidUSDC)
        let fee = Amount(baseUnits: 2_500, of: Fixtures.hyperliquidUSDC)
        let gain = Amount(baseUnits: 12_000_000, of: Fixtures.hyperliquidUSDC)
        let balance = try stake.subtracting(fee).adding(gain)
        #expect(balance.baseUnits == 111_997_500)
        #expect(stake - fee + gain == balance)
        #expect(stake * Fraction(percent: 50) == Amount(baseUnits: 50_000_000, of: Fixtures.hyperliquidUSDC))
        #expect(stake / Fraction(integer: 4) == Amount(baseUnits: 25_000_000, of: Fixtures.hyperliquidUSDC))
        #expect(Fraction(balance - stake, over: stake) == Fraction(basisPoints: 1_199) + Fraction(Amount(baseUnits: 75, of: Fixtures.hyperliquidUSDC), over: Amount(baseUnits: 1_000_000, of: Fixtures.hyperliquidUSDC)))
        #expect(stake < balance)
        #expect(!(-fee).isZero && (-fee).isNegative)
        #expect(Amount.zero(of: Fixtures.hyperliquidUSDC).isZero)
        let size = Amount(baseUnits: 15_000, of: Fixtures.hyperliquidBTC)
        #expect(size + size == Amount(baseUnits: 30_000, of: Fixtures.hyperliquidBTC))
        let stored: Amount = try balance.toJSON().fromJSON()
        #expect(stored == balance)
    }

    @Test func aKrakenStreamCountsInKrakensDollarAndNeverConverts() throws {
        let deposit = Amount(baseUnits: 10_000_000, of: Fixtures.krakenUSD)         // 1000.0000 at 4
        let proceeds = Amount(baseUnits: 1_013_425, of: Fixtures.krakenUSD)         // 101.3425
        let balance = deposit + proceeds
        #expect(balance == Amount(baseUnits: 11_013_425, of: Fixtures.krakenUSD))
        #expect(balance.instance == Fixtures.krakenUSD)
        #expect(throws: AmountError.instanceConflict(Fixtures.krakenUSD, Fixtures.usd)) {
            try balance.adding(Amount(baseUnits: 1, of: Fixtures.usd))
        }
    }
}
