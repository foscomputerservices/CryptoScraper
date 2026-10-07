// D33 — A stream's unit of account is an exchange holding; a total across exchanges counts in the home ("Home").
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.3: "A stream lives on one exchange chain, so its
// ledger's arithmetic stays within its instances and never converts. Its unit of account is that exchange's holding:
// `exchange:hyperliquid:USDC` at 6, `exchange:kraken:USD` at 4, `exchange:coinbase:USD` at 2." And § 3.2's Binance
// vectors, § 6's amount and stream bullets, and § 7.3 "Home": "A total across exchanges counts in the asset's home
// instance; each side converts to it through the map, and the total refuses where digits would be lost."

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
import Testing

@Suite("D33 Unit of account")
struct D33_UnitOfAccountTests {
    private let hyperliquidUSDC = AssetInstance(HyperliquidHolding.usdc)
    private let krakenUSD = AssetInstance(KrakenHolding.usd)
    // invented: CoinbaseHolding.usd — implied by "Coinbase's USD"; not written out
    private let coinbaseUSD = AssetInstance(CoinbaseHolding.usd)
    private let binanceUSDT = AssetInstance(BinanceHolding.usdt)
    private let ethereumUSDT = EIP155.Ethereum.usdt.instance

    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "A Hyperliquid stream's stake is `Amount(whole: 100, of: exchange:hyperliquid:USDC)`, 100,000,000 base units."
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func hyperliquidStakeIsAHundredMillionBaseUnits() throws {
        #expect(try Amount(whole: 100, of: hyperliquidUSDC, in: registry()).baseUnits == 100_000_000)
    }

    // "its arithmetic performs no lookup: a registry that throws on every call is passed, and the arithmetic still runs"
    @Test func arithmeticRunsAgainstARegistryThatThrows() throws {
        let throwing = try AssetRegistry([])   // every lookup in it throws
        #expect(throws: AssetRegistryError.undeclaredInstance(hyperliquidUSDC)) {
            try throwing.decimals(of: hyperliquidUSDC)
        }
        let stake = Amount(baseUnits: 100_000_000, of: hyperliquidUSDC)
        let fee = Amount(baseUnits: 2_500, of: hyperliquidUSDC)
        let after = stake - fee
        #expect(after.baseUnits == 99_997_500)
        #expect((after * Fraction(percent: 50)).baseUnits == 49_998_750)
        #expect(try after.adding(fee) == stake)
    }

    // "Its postings all count in Hyperliquid instances" — the arithmetic keeps the instance
    @Test func hyperliquidArithmeticStaysInItsInstance() {
        let stake = Amount(baseUnits: 100_000_000, of: hyperliquidUSDC)
        #expect((stake - Amount(baseUnits: 1, of: hyperliquidUSDC)).instance == hyperliquidUSDC)
    }

    // "A Kraken stream's unit of account is `exchange:kraken:USD`, and its balance never converts."
    @Test func krakenBalanceStaysInKrakensDollar() {
        let balance = Amount(baseUnits: 11_013_425, of: krakenUSD) + Amount(baseUnits: 1, of: krakenUSD)
        #expect(balance.instance == krakenUSD)
        #expect(balance.baseUnits == 11_013_426)
    }

    // "A Kraken dollar at 4 held exactly: 1101.3425 in `exchange:kraken:USD` round-trips"
    @Test func krakenDollarAtFourRoundTrips() throws {
        let balance = Amount(baseUnits: 11_013_425, of: krakenUSD)
        let back: Amount = try balance.toJSON().fromJSON()
        #expect(back == balance)
    }

    // "converting it to `iso4217:USD` throws `notRepresentable`"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenDollarWithFourDigitsDoesNotConvertToTheDollar() throws {
        let balance = Amount(baseUnits: 11_013_425, of: krakenUSD)
        let registry = try registry()
        #expect(throws: AmountError.notRepresentable(balance, in: ISO4217.usd.instance)) {
            try balance.converted(to: ISO4217.usd.instance, in: registry)
        }
    }

    // "Up is exact. Ethereum's tether at 6 converted to Binance's holding at 8 multiplies by 100." (§ 3.2)
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func ethereumTetherToBinanceIsTimesAHundred() throws {
        let converted = try Amount(baseUnits: 123_456, of: ethereumUSDT).converted(to: binanceUSDT, in: registry())
        #expect(converted == Amount(baseUnits: 12_345_600, of: binanceUSDT))
    }

    // "Binance's 0.12345678 USDT converted to Ethereum's 6 throws `notRepresentable`"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func binanceDustDoesNotConvertDown() throws {
        let dust = Amount(baseUnits: 12_345_678, of: binanceUSDT)
        let registry = try registry()
        #expect(throws: AmountError.notRepresentable(dust, in: ethereumUSDT)) {
            try dust.converted(to: ethereumUSDT, in: registry)
        }
    }

    // "0.123456 converts"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func binanceSixDigitsConvertsDown() throws {
        let clean = Amount(baseUnits: 12_345_600, of: binanceUSDT)
        #expect(try clean.converted(to: ethereumUSDT, in: registry()) == Amount(baseUnits: 123_456, of: ethereumUSDT))
    }

    // "`binanceUSDT.adding(ethereumUSDT)` throws `instanceConflict`"
    @Test func addingBinanceAndEthereumTetherThrows() {
        let a = Amount(baseUnits: 1, of: binanceUSDT)
        let b = Amount(baseUnits: 1, of: ethereumUSDT)
        #expect(throws: AmountError.instanceConflict(binanceUSDT, ethereumUSDT)) { try a.adding(b) }
    }

    // "tether to USDC throws `notEquivalent`" — Binance's tether to Hyperliquid's USDC
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func binanceTetherToHyperliquidUSDCIsNotEquivalent() throws {
        let registry = try registry()
        #expect(throws: AmountError.notEquivalent(binanceUSDT, hyperliquidUSDC)) {
            try Amount(baseUnits: 1, of: binanceUSDT).converted(to: hyperliquidUSDC, in: registry)
        }
    }

    // "Home": a Kraken-plus-Coinbase total counts in `iso4217:USD`, never as `exchange:kraken:USD`
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenPlusCoinbaseCountsInTheDollar() throws {
        let registry = try registry()
        let kraken = Amount(baseUnits: 11_013_400, of: krakenUSD)    // 1101.3400
        let coinbase = Amount(baseUnits: 2_500, of: coinbaseUSD)     // 25.00
        let home = ISO4217.usd.instance
        let total = try kraken.converted(to: home, in: registry) + coinbase.converted(to: home, in: registry)
        #expect(total.instance == home)
        #expect(total == Amount(baseUnits: 112_634, of: home))
    }

    // "Home": "the total refuses where digits would be lost" — a refusal shows which balance carries the extra digits
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenWithExtraDigitsRefusesTheTotal() throws {
        let registry = try registry()
        let kraken = Amount(baseUnits: 11_013_425, of: krakenUSD)
        #expect(throws: AmountError.notRepresentable(kraken, in: ISO4217.usd.instance)) {
            try kraken.converted(to: ISO4217.usd.instance, in: registry)
        }
    }

    // "Home": tether across exchanges counts in Ethereum's tether at 6
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func tetherTotalCountsInEthereumsTether() throws {
        let registry = try registry()
        #expect(try registry.declaration(of: .usdt).instances.first?.instance == ethereumUSDT)
        let total = try Amount(baseUnits: 100_000_000, of: binanceUSDT).converted(to: ethereumUSDT, in: registry)
            + Amount(baseUnits: 1_000_000, of: ethereumUSDT)
        #expect(total == Amount(baseUnits: 2_000_000, of: ethereumUSDT))
    }
}
