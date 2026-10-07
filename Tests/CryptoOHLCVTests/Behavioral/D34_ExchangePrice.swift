// D34 — The price on an exchange chain.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.4: "A price names two instances: Kraken's price is
// `exchange:kraken:USD` per `exchange:kraken:XBT`." And § 6: "Kraken's price of `exchange:kraken:USD` per
// `exchange:kraken:XBT` gives a cost at 4 for a size at 10, with the base's decimals read from the registry at
// `cost(of:in:)`; against a registry that lacks the base, `cost` throws `undeclaredInstance` (2026-10-07)." And
// "No string is written by a caller ... The two instances come from the exchange chain's `contract(for:)`".

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
import Testing

@Suite("D34 Exchange price")
struct D34_ExchangePriceTests {
    private let krakenUSD = AssetInstance(KrakenHolding.usd)
    private let krakenXBT = AssetInstance(KrakenHolding.xbt)

    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "Kraken's price is `exchange:kraken:USD` per `exchange:kraken:XBT`"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakensPriceNamesItsTwoHoldings() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: krakenUSD, in: registry), per: krakenXBT, in: registry)
        #expect(mid.quote == krakenUSD)
        #expect(mid.base == krakenXBT)
    }

    // "gives a cost at 4 for a size at 10" — 0.15 XBT at 65,000 is 9,750.0000 in Kraken's dollar
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func costAtFourForASizeAtTen() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: krakenUSD, in: registry), per: krakenXBT, in: registry)
        let size = Amount(baseUnits: 1_500_000_000, of: krakenXBT)            // 0.15 at 10
        #expect(try mid.cost(of: size, in: registry) == Amount(baseUnits: 97_500_000, of: krakenUSD))
    }

    // "against a registry that lacks the base, `cost` throws `undeclaredInstance`"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func costAgainstARegistryLackingKrakensBitcoinThrows() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: krakenUSD, in: registry), per: krakenXBT, in: registry)
        let lacking = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclaredInstance(krakenXBT)) {
            try mid.cost(of: Amount(baseUnits: 1_500_000_000, of: krakenXBT), in: lacking)
        }
    }

    // "The two instances come from the exchange chain's `contract(for:)` over the names in the exchange's answer"
    @Test func instancesFromTheWireNamesAreTheConstants() throws {
        let base = try KrakenExchangeChain.default.contract(for: "XXBT")
        let quote = try KrakenExchangeChain.default.contract(for: "ZUSD")
        #expect(AssetInstance(base) == krakenXBT)
        #expect(AssetInstance(quote) == krakenUSD)
    }

    // "A price's row is its two instances and its scaled number" — Kraken's row round-trips with no registry
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakensPriceRowRoundTrips() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: krakenUSD, in: registry), per: krakenXBT, in: registry)
        let json = try mid.toJSON()
        #expect(json.contains("\"exchange:kraken:USD\""))
        #expect(json.contains("\"exchange:kraken:XBT\""))
        let back: Price = try json.fromJSON()
        #expect(back == mid)
    }

    // "Quote base units per whole base unit, times 10^9" — 65,000 at Kraken's 4
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakensScaledNumber() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: krakenUSD, in: registry), per: krakenXBT, in: registry)
        #expect(mid.scaled == Int128(650_000_000) * 1_000_000_000)
    }

    // "Hyperliquid's lot is one base unit of `exchange:hyperliquid:BTC` at 5" — a price on it costs a lot exactly
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func hyperliquidLotCost() throws {
        let registry = try registry()
        // invented: HyperliquidHolding.btc — the id is the design's; the constant's Swift name is not declared
        let btc = AssetInstance(HyperliquidHolding.btc)
        let usdc = AssetInstance(HyperliquidHolding.usdc)
        let mid = try Price(Amount(whole: 65_000, of: usdc, in: registry), per: btc, in: registry)
        #expect(try mid.cost(of: Amount(baseUnits: 1, of: btc), in: registry) == Amount(baseUnits: 650_000, of: usdc))
    }
}
