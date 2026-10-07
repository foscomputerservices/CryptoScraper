// D53 — What the Kraken client hands up (C30 as amended).
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 5.3: "A client, the candle client included, reads the
// exchange's names off the wire, asks its exchange chain's `contract(for:)`, and from then on works in the holding
// constants. At its init each client adds its exchange's declarations to its registry (the same declarations twice are
// one) and registers the chain with your `BlockChains`. ... A name the table lacks gives a market with `nil` holdings; a
// money value in it is refused." And "The units check at start (AR45) compares the decimals the exchange states with
// the declared instance's. Any difference is a finding". And the owner's ruling of 2026-10-07: a client never builds an
// identity from an exchange's string; an unlisted name is a finding, never a minted holding.
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoKraken
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D53 Kraken client")
struct D53_KrakenClientTests {
    // invented: KrakenClient(credential:session:registry:), KrakenCredential.stub() and RecordedKraken.session(answering:) —
    // "each client takes a registry at init (default `.shared`)" (§ 5.3) and "FOSFoundation's mockable session with
    // recorded responses" (§ 8.6); the initializer's labels and the recording's loader are not declared
    private func client(_ recording: String, registry: AssetRegistry? = nil) throws -> KrakenClient {
        try KrakenClient(credential: .stub(), session: RecordedKraken.session(answering: recording),
                         registry: registry ?? AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    // "a recorded market lands on `.xbt` and `.usd` with no string compared outside the table"
    @Test func recordedMarketLandsOnTheConstants() async throws {
        let markets = try await client("AssetPairs").markets()
        let xbtusd = try #require(markets.first { $0.base == AssetInstance(KrakenHolding.xbt) && $0.quote == AssetInstance(KrakenHolding.usd) })
        #expect(xbtusd.lotSize?.instance == AssetInstance(KrakenHolding.xbt))
    }

    // "every wire name in the recorded listing resolves through `contract(for:)` to a declared holding or is reported as a finding, none minted"
    @Test func everyListedHoldingIsDeclared() async throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let markets = try await client("AssetPairs", registry: registry).markets()
        for market in markets {
            for instance in [market.base, market.quote].compactMap({ $0 }) {
                #expect(instance.chainId == KrakenExchangeChain.default.id)
                _ = try registry.decimals(of: instance)
            }
        }
    }

    // "A name the table lacks gives a market with `nil` holdings" — with the wire's names kept as facts
    @Test(.disabled("Classified 2026-10-07: no recording AssetPairs-unlisted (a pair whose base no table row names); see the identity ledger")) func unlistedNameGivesNilHoldings() async throws {
        // the recording "AssetPairs-unlisted" carries one pair whose base no table row names
        let markets = try await client("AssetPairs-unlisted").markets()
        let unlisted = try #require(markets.first { $0.base == nil })
        #expect(unlisted.lotSize == nil)
        #expect(unlisted.minimumOrder == nil)
        #expect(!unlisted.baseSymbol.text.isEmpty)
    }

    // owner, 2026-10-07: "an unlisted name is a finding, never a minted holding" — no instance outside the table appears
    @Test(.disabled("Classified 2026-10-07: no recording AssetPairs-unlisted (a pair whose base no table row names); see the identity ledger")) func noHoldingIsMintedFromTheWire() async throws {
        let markets = try await client("AssetPairs-unlisted").markets()
        let known = Set((KrakenExchangeChain.importedWireNames + KrakenExchangeChain.overrideWireNames)
            .compactMap { try? AssetInstance(KrakenExchangeChain.default.contract(for: $0)) })
        // invented: KrakenExchangeChain.importedWireNames / .overrideWireNames — the two row sets of § 2.7; no member is declared
        for instance in markets.flatMap({ [$0.base, $0.quote] }).compactMap({ $0 }) {
            #expect(known.contains(instance))
        }
    }

    // "a money value in it is refused"
    @Test(.disabled("Classified 2026-10-07: no recording AssetPairs-unlisted (a pair whose base no table row names); see the identity ledger")) func moneyValueOnAnUnlistedMarketIsRefused() async throws {
        let client = try client("AssetPairs-unlisted")
        let markets = try await client.markets()
        let unlisted = try #require(markets.first { $0.base == nil })
        await #expect(throws: (any Error).self) { _ = try await client.orderBook(market: unlisted.name) }
    }

    // "The exchange's symbol and decimals are handed up as facts beside them" — Kraken states XBT at 10
    @Test func factsBesideTheHoldings() async throws {
        let markets = try await client("AssetPairs").markets()
        let xbtusd = try #require(markets.first { $0.base == AssetInstance(KrakenHolding.xbt) })
        #expect(xbtusd.baseDecimals == 10)
    }

    // "Kraken's recorded Assets answer yields `exchange:kraken:XBT` at 10 and `exchange:kraken:USD` at 4, each declared."
    @Test(.disabled("Classified 2026-10-07: needs KrakenClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; see the identity ledger")) func unitsCheckAgreesOnTheRecordedAnswer() async throws {
        // invented: KrakenClient.unitsCheck() -> [ExchangeUnitsFinding] — "The units check at start (AR45)" names no member
        #expect(try await client("Assets").unitsCheck().isEmpty)
    }

    // "The client's units check: a recorded answer with Kraken's XBT at 8 raises the finding."
    @Test(.disabled("Classified 2026-10-07: needs KrakenClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; and no recording Assets-XBT-at-8; see the identity ledger")) func unitsCheckRaisesTheFindingAtEight() async throws {
        // invented: as above; ExchangeUnitsFinding(instance:stated:declared:) — the finding's shape is not declared
        let findings = try await client("Assets-XBT-at-8").unitsCheck()
        #expect(findings.contains { $0.instance == AssetInstance(KrakenHolding.xbt) && $0.stated == 8 && $0.declared == 10 })
    }

    // "At its init each client adds its exchange's declarations to its registry"
    @Test func initAddsKrakensDeclarations() throws {
        let registry = try AssetRegistry([])
        _ = try client("Assets", registry: registry)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.xbt)) == 10)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.usd)) == 4)
    }

    // "(the same declarations twice are one)"
    @Test func twoClientsOnOneRegistry() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        _ = try client("Assets", registry: registry)
        _ = try client("Assets", registry: registry)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.xbt)) == 10)
    }

    // "and registers the chain with your `BlockChains`"
    @Test func initRegistersTheChain() throws {
        _ = try client("Assets")
        #expect((BlockChains.contract(of: AssetInstance(KrakenHolding.usd)) as? KrakenHolding) == .usd)
    }

    // "Every money value is an `Amount` in the exchange's instance." — the account's balance is in Kraken's dollar
    @Test func balanceIsInKrakensDollar() async throws {
        let state = try await client("Balance").accountState(account: "bedrock")
        #expect(state.balance.instance == AssetInstance(KrakenHolding.usd))
    }

    // "Every money value is an `Amount` in the exchange's instance." — the book's prices are USD per XBT
    @Test func bookPricesAreKrakensHoldings() async throws {
        let client = try client("Ticker-XBTUSD")
        let markets = try await client.markets()
        let xbtusd = try #require(markets.first { $0.base == AssetInstance(KrakenHolding.xbt) })
        let book = try await client.orderBook(market: xbtusd.name)
        #expect(book.mid.base == AssetInstance(KrakenHolding.xbt))
        #expect(book.mid.quote == AssetInstance(KrakenHolding.usd))
        #expect(book.baseVolume.instance == AssetInstance(KrakenHolding.xbt))
        #expect(book.quoteVolume.instance == AssetInstance(KrakenHolding.usd))
    }

    // "`KrakenHolding.xbt.wireName` is the name Kraken's recorded order accepts"
    @Test(.disabled("Classified 2026-10-07: no recording of an order request (the recordings are Kraken's answers; AddOrder's descr names the pair, never the asset); see the identity ledger")) func wireNameIsWhatTheRecordedOrderAccepts() throws {
        // invented: RecordedKraken.acceptedOrderAssetName(in:) — reads the asset name out of the recorded order request
        #expect(KrakenHolding.xbt.wireName == RecordedKraken.acceptedOrderAssetName(in: "AddOrder"))
    }
}
