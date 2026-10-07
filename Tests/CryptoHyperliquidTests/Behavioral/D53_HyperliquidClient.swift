// D53 — What the Hyperliquid client hands up (C30 as amended).
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 5.3: "A client ... reads the exchange's names off the
// wire, asks its exchange chain's `contract(for:)`, and from then on works in the holding constants." and "Hyperliquid's
// lot is one base unit of `exchange:hyperliquid:BTC` at 5." And § 1.3: "Hyperliquid's coins: keys as Hyperliquid spells
// them, case included, since its wire names are its only names" and "Hyperliquid's `\"four-hour-2x\"` is
// `exchange:hyperliquid:four-hour-2x` as an account". And § 7.2: "Hyperliquid's `kPEPE` is a thousand PEPE ... `kPEPE`
// joins no class until a scale is designed." And "The units check at start (AR45)".
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D53 Hyperliquid client")
struct D53_HyperliquidClientTests {
    // invented: the `registry:` label and RecordedHyperliquid.session(answering:) / HyperliquidAgentKey.stub() — C31's example
    // gives `HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket, session: session)`; the registry label and the recording loader are not declared
    private func client(_ recording: String, registry: AssetRegistry? = nil) throws -> HyperliquidClient {
        try HyperliquidClient(credential: .agentKey(.stub()), endpoint: .testMarket,
                              session: RecordedHyperliquid.session(answering: recording),
                              registry: registry ?? AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    // invented: HyperliquidHolding.btc / .kPEPE — the ids are the design's; the constants' Swift names are not declared
    private let btc = AssetInstance(HyperliquidHolding.btc)
    private let usdc = AssetInstance(HyperliquidHolding.usdc)

    // "Hyperliquid's lot is one base unit of `exchange:hyperliquid:BTC` at 5."
    @Test func btcLotIsOneBaseUnit() async throws {
        let markets = try await client("meta").markets()
        let perp = try #require(markets.first { $0.base == btc })
        #expect(perp.lotSize == Amount(baseUnits: 1, of: btc))
        #expect(perp.baseDecimals == 5)
    }

    // "The exchange's main contract is the holding its account's value is stated in: Hyperliquid's USDC"
    @Test func perpQuoteIsHyperliquidsUSDC() async throws {
        let markets = try await client("meta").markets()
        let perp = try #require(markets.first { $0.base == btc })
        #expect(perp.quote == usdc)
        #expect(perp.isPerpetual)
    }

    // "keys as Hyperliquid spells them, case included"
    @Test(.disabled("Classified 2026-10-07: asserts the kPEPE market's base is its holding; the design says a holding the statement does not declare leaves the market's base nil (C30 as § 5.3 amends it), and kPEPE joins no class (§ 7.2); see the identity ledger")) func kPEPEKeepsItsCase() async throws {
        let markets = try await client("meta").markets()
        let kpepe = try #require(markets.first { $0.base == AssetInstance(HyperliquidHolding.kPEPE) })
        #expect(kpepe.base?.address == "kPEPE")
    }

    // "`kPEPE` joins no class until a scale is designed."
    @Test func kPEPEJoinsNoClass() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        _ = try client("meta", registry: registry)
        let kpepe = AssetInstance(HyperliquidHolding.kPEPE)
        #expect(throws: AssetRegistryError.undeclaredInstance(kpepe)) { try registry.asset(of: kpepe) }
    }

    // "every wire name in the recorded listing resolves through `contract(for:)` to a declared holding or is reported as a finding, none minted"
    @Test func everyListedHoldingIsOnHyperliquidsChain() async throws {
        let markets = try await client("meta").markets()
        for instance in markets.flatMap({ [$0.base, $0.quote] }).compactMap({ $0 }) {
            #expect(instance.chainId == HyperliquidExchangeChain.default.id)
        }
    }

    // "A name the table lacks gives a market with `nil` holdings"
    @Test(.disabled("Classified 2026-10-07: no recording meta-unlisted (a coin no table row names); see the identity ledger")) func unlistedCoinGivesNilHoldings() async throws {
        // the recording "meta-unlisted" carries one coin no table row names
        let markets = try await client("meta-unlisted").markets()
        let unlisted = try #require(markets.first { $0.base == nil })
        #expect(unlisted.lotSize == nil)
        #expect(!unlisted.baseSymbol.text.isEmpty)
    }

    // "The units check at start (AR45) compares the decimals the exchange states with the declared instance's."
    @Test(.disabled("Classified 2026-10-07: needs HyperliquidClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; see the identity ledger")) func unitsCheckAgreesOnTheRecordedMeta() async throws {
        // invented: HyperliquidClient.unitsCheck() -> [ExchangeUnitsFinding] — no member is declared
        #expect(try await client("meta").unitsCheck().isEmpty)
    }

    // "Any difference is a finding" — BTC stated at another size-decimals
    @Test(.disabled("Classified 2026-10-07: needs HyperliquidClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; and no recording meta-BTC-at-4; see the identity ledger")) func unitsCheckRaisesAFinding() async throws {
        // invented: as above; ExchangeUnitsFinding(instance:stated:declared:)
        let findings = try await client("meta-BTC-at-4").unitsCheck()
        #expect(findings.contains { $0.instance == btc && $0.stated == 4 && $0.declared == 5 })
    }

    // "Hyperliquid's `\"four-hour-2x\"` is `exchange:hyperliquid:four-hour-2x` as an account" — its state counts in USDC
    @Test(.disabled("Classified 2026-10-07: asserts the recorded sub-account's state is handed up; it holds a position in NEO, which Hyperliquid's table does not declare, and the design says a money value in an undeclared holding is refused (§ 5.3); see the identity ledger")) func subAccountStateCountsInUSDC() async throws {
        let state = try await client("clearinghouseState").accountState(account: "four-hour-2x")
        #expect(state.balance.instance == usdc)
        #expect(state.withdrawable.instance == usdc)
    }

    // "Every money value is an `Amount` in the exchange's instance." — a position's size is in the BTC holding
    @Test(.disabled("Classified 2026-10-07: asserts the recorded sub-account's state is handed up; it holds a position in NEO, which Hyperliquid's table does not declare, and the design says a money value in an undeclared holding is refused (§ 5.3); see the identity ledger")) func positionUnitsAreInTheBaseHolding() async throws {
        let state = try await client("clearinghouseState").accountState(account: "four-hour-2x")
        for position in state.positions {
            #expect(position.units.instance.chainId == HyperliquidExchangeChain.default.id)
            #expect(position.entryPrice.base == position.units.instance)
            #expect(position.mark.quote == usdc)
        }
    }

    // "At its init each client adds its exchange's declarations to its registry"
    @Test func initAddsHyperliquidsDeclarations() throws {
        let registry = try AssetRegistry([])
        _ = try client("meta", registry: registry)
        #expect(try registry.decimals(of: usdc) == 6)
        #expect(try registry.decimals(of: btc) == 5)
    }

    // "and registers the chain with your `BlockChains`"
    @Test func initRegistersTheChain() throws {
        _ = try client("meta")
        #expect((BlockChains.contract(of: usdc) as? HyperliquidHolding) == .usdc)
    }
}
