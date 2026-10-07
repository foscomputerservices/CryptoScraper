// D27 — The exchange tables, generated and hand-written.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.7: "The table is the union of the two row sets; a
// test refuses a wire name present in both." and "Regeneration adds rows and wire names and changes symbols; it refuses
// to change an existing row's decimals or class". And § 6: "every wire name in the recorded listing resolves through
// `contract(for:)` to a declared holding or is reported as a finding, none minted".

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D27 Exchange tables")
struct D27_ExchangeTablesTests {
    // "a test refuses a wire name present in both" — Kraken
    @Test func krakenImportedAndOverrideRowsAreDisjoint() {
        // invented: KrakenExchangeChain.importedWireNames / .overrideWireNames — the two row sets of § 2.7's files; no member is declared
        #expect(Set(KrakenExchangeChain.importedWireNames).isDisjoint(with: KrakenExchangeChain.overrideWireNames))
    }

    // "a test refuses a wire name present in both" — Binance, Coinbase, Hyperliquid
    @Test func theOtherTablesAreDisjoint() {
        // invented: as above, for each exchange chain
        #expect(Set(BinanceExchangeChain.importedWireNames).isDisjoint(with: BinanceExchangeChain.overrideWireNames))
        #expect(Set(CoinbaseExchangeChain.importedWireNames).isDisjoint(with: CoinbaseExchangeChain.overrideWireNames))
        #expect(Set(HyperliquidExchangeChain.importedWireNames).isDisjoint(with: HyperliquidExchangeChain.overrideWireNames))
    }

    // "The table is the union of the two row sets" — every row of either set resolves
    @Test func everyKrakenRowResolves() throws {
        for name in KrakenExchangeChain.importedWireNames + KrakenExchangeChain.overrideWireNames {
            _ = try KrakenExchangeChain.default.contract(for: name)
        }
    }

    // "Hyperliquid's USDC (no meta lists it)" stays hand-written — it is in the override set
    @Test func hyperliquidUSDCIsHandWritten() throws {
        #expect(HyperliquidExchangeChain.overrideWireNames.contains(HyperliquidHolding.usdc.wireName))
        #expect(try HyperliquidExchangeChain.default.contract(for: HyperliquidHolding.usdc.wireName) == .usdc)
    }

    // "every wire name ... resolves through `contract(for:)` to a declared holding" — declared means the registry knows its decimals
    @Test func everyKrakenRowIsADeclaredInstance() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        // invented: KrakenExchangeChain.declarations — "At its init each client adds its exchange's declarations to its registry" (§ 5.3) names no member
        try registry.add(KrakenExchangeChain.declarations)
        for name in KrakenExchangeChain.importedWireNames + KrakenExchangeChain.overrideWireNames {
            let holding = try KrakenExchangeChain.default.contract(for: name)
            _ = try registry.decimals(of: AssetInstance(holding))
        }
    }

    // "the same declarations twice are one" (§ 5.3) — adding an exchange's declarations twice is no error
    @Test func addingAnExchangesDeclarationsTwiceIsOne() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        try registry.add(KrakenExchangeChain.declarations)
        try registry.add(KrakenExchangeChain.declarations)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.xbt)) == 10)
    }

    // "the row's class is `Assets.<id>`, never a symbol match" — Kraken's XBT is in Assets.bitcoin
    @Test func krakenXBTIsInTheBitcoinClass() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        try registry.add(KrakenExchangeChain.declarations)
        #expect(try registry.asset(of: AssetInstance(KrakenHolding.xbt)) == Assets.bitcoin.asset)
    }

    // "What the table buys: when an exchange renames on the wire, one row of one table changes, and every stored id ... stands."
    @Test func twoWireNamesOneStoredId() throws {
        let fromLegacy = try KrakenExchangeChain.default.contract(for: "XXBT")
        let fromAltName = try KrakenExchangeChain.default.contract(for: "XBT")
        #expect(AssetInstance(fromLegacy).id == AssetInstance(fromAltName).id)
    }
}
