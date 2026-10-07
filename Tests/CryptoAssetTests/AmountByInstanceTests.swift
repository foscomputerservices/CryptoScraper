// AmountByInstanceTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Testing

// Design § 6, "The amount": an amount carries its instance and nothing else; a plain add across instances is
// refused, and the one path between two instances is the map, exactly or not at all (§ 3.1, § 3.2).

@Suite("The amount by instance")
struct AmountByInstanceTests {
    @Test func aCrossInstanceAddIsRefusedAsAPlainAdd() {
        let binance = Amount(baseUnits: 12_345_678, of: Fixtures.binanceUSDT)
        let ethereum = Amount(baseUnits: 123_456, of: Fixtures.usdt)
        #expect(throws: AmountError.instanceConflict(Fixtures.binanceUSDT, Fixtures.usdt)) {
            try binance.adding(ethereum)
        }
    }

    @Test func aCrossInstancePlusTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 12_345_678, of: Fixtures.binanceUSDT) + Amount(baseUnits: 123_456, of: Fixtures.usdt)
        }
    }

    @Test func upIsExact() throws {
        let registry = Fixtures.registryWithHoldings()
        let ethereum = Amount(baseUnits: 1_234_567, of: Fixtures.usdt)                    // 1.234567 at 6
        #expect(try ethereum.converted(to: Fixtures.binanceUSDT, in: registry) == Amount(baseUnits: 123_456_700, of: Fixtures.binanceUSDT))
    }

    @Test func downRefusesLostDigits() throws {
        let registry = Fixtures.registryWithHoldings()
        let dust = Amount(baseUnits: 12_345_678, of: Fixtures.binanceUSDT)                // 0.12345678 at 8
        #expect(throws: AmountError.notRepresentable(dust, in: Fixtures.usdt)) {
            try dust.converted(to: Fixtures.usdt, in: registry)
        }
        let even = Amount(baseUnits: 12_345_600, of: Fixtures.binanceUSDT)                // 0.123456 at 8
        #expect(try even.converted(to: Fixtures.usdt, in: registry) == Amount(baseUnits: 123_456, of: Fixtures.usdt))
    }

    @Test func tetherToUSDCIsNotEquivalent() {
        let registry = Fixtures.registryWithHoldings()
        let tether = Amount(baseUnits: 1_000_000, of: Fixtures.usdt)
        #expect(throws: AmountError.notEquivalent(Fixtures.usdt, Fixtures.usdc)) {
            try tether.converted(to: Fixtures.usdc, in: registry)
        }
    }

    @Test func aConversionToAnUndeclaredInstanceIsATypedError() {
        let registry = Fixtures.registryWithHoldings()
        let account = Fixtures.instance("exchange:hyperliquid:four-hour-2x")
        #expect(throws: AssetRegistryError.undeclaredInstance(account)) {
            try Amount(baseUnits: 1, of: Fixtures.hyperliquidUSDC).converted(to: account, in: registry)
        }
    }

    @Test func anUpConversionThatOverflowsIsNotRepresentable() {
        let registry = Fixtures.registryWithHoldings()
        let huge = Amount(baseUnits: .max, of: Fixtures.usdc)
        #expect(throws: AmountError.notRepresentable(huge, in: Fixtures.bscUSDC)) {
            try huge.converted(to: Fixtures.bscUSDC, in: registry)
        }
    }

    @Test func aKrakenDollarAtFourIsHeldExactly() throws {
        let registry = Fixtures.registryWithHoldings()
        let balance = Amount(baseUnits: 11_013_425, of: Fixtures.krakenUSD)               // 1101.3425
        let decoded: Amount = try balance.toJSON().fromJSON()
        #expect(decoded == balance)
        #expect(throws: AmountError.notRepresentable(balance, in: Fixtures.usd)) {
            try balance.converted(to: Fixtures.usd, in: registry)
        }
    }

    @Test func wholeUnitsReadTheInstancesDecimals() throws {
        let registry = Fixtures.registryWithHoldings()
        #expect(try Amount(whole: 1, of: Fixtures.krakenXBT, in: registry).baseUnits == 10_000_000_000)
        #expect(try Amount(whole: 1, of: Fixtures.hyperliquidBTC, in: registry).baseUnits == 100_000)
        #expect(try Amount(whole: 100, of: Fixtures.hyperliquidUSDC, in: registry).baseUnits == 100_000_000)
    }

    @Test func wholeUnitsOfAnUndeclaredInstanceThrow() {
        let registry = Fixtures.registryWithHoldings()
        let account = Fixtures.instance("exchange:hyperliquid:four-hour-2x")
        #expect(throws: AssetRegistryError.undeclaredInstance(account)) {
            try Amount(whole: 1, of: account, in: registry)
        }
    }

    @Test func aNamedUnitCountsOnAnotherInstanceAtItsPlace() throws {
        let registry = Fixtures.registryWithHoldings()
        // Kraken's XBT is 10 decimals; a satoshi is 10^0 of the home's 8, so 100 of Kraken's base units
        #expect(try Amount(count: 1, in: Fixtures.satoshi, of: Fixtures.krakenXBT, in: registry).baseUnits == 100)
        let oneBitcoin = Amount(baseUnits: 10_000_000_000, of: Fixtures.krakenXBT)
        #expect(try oneBitcoin.count(in: Fixtures.satoshi, in: registry) == (count: 100_000_000, remainder: 0))
        #expect(try oneBitcoin.count(in: Fixtures.bitcoin, in: registry) == (count: 1, remainder: 0))
    }

    @Test func aUnitFinerThanTheInstancesBaseUnitIsOutOfRange() {
        let registry = Fixtures.registryWithHoldings()
        // Hyperliquid's BTC is 5 decimals: a satoshi is finer than its base unit
        #expect(throws: AssetError.unitOutOfRange(Fixtures.satoshi)) {
            try Amount(count: 1, in: Fixtures.satoshi, of: Fixtures.hyperliquidBTC, in: registry)
        }
    }

    @Test func theC3VectorsStandWithinOneInstance() throws {
        let registry = Fixtures.registryWithHoldings()
        let stake = try Amount(whole: 100, of: Fixtures.hyperliquidUSDC, in: registry)
        let fee = Amount(baseUnits: 2_500, of: Fixtures.hyperliquidUSDC)
        #expect((stake - fee).baseUnits == 99_997_500)
        #expect(stake * Fraction(percent: 50) == Amount(baseUnits: 50_000_000, of: Fixtures.hyperliquidUSDC))
        #expect(stake / Fraction(integer: 2) == Amount(baseUnits: 50_000_000, of: Fixtures.hyperliquidUSDC))
        let tip = try Amount(count: 5, in: Fixtures.gwei, of: Fixtures.eth, in: registry)
        #expect(tip.baseUnits == 5_000_000_000)
        #expect(try tip.count(in: Fixtures.gwei, in: registry) == (count: 5, remainder: 0))
    }
}
