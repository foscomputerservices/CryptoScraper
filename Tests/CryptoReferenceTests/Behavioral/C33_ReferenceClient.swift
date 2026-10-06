// C33_ReferenceClient.swift — C33 and D13: the reference client's protocol, its value, the CoinMarketCap conformer
// reading recorded responses, and its typed errors

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("C33: the reference client")
struct C33_ReferenceClientTests {
    let btc = try! AssetSymbol(validating: "BTC")
    let eth = try! AssetSymbol(validating: "ETH")

    func client(_ responses: [RecordedResponse]) -> (CoinMarketCapClient, RecordedSession) {
        let session = RecordedSession(responses)
        return (behavioralCoinMarketCapClient(session: session), session)
    }

    // MARK: The protocol and the value

    /// A conformer written from C33's declaration alone
    struct ScriptedReference: ReferenceClient {
        let assets: [ReferenceClientAsset]
        func reference(symbols: [AssetSymbol]) async throws -> [ReferenceClientAsset] {
            assets.filter { symbols.contains($0.symbol) }
        }
    }

    func consume<R: ReferenceClient>(_ client: R, symbols: [AssetSymbol]) async throws -> [ReferenceClientAsset] {
        try await client.reference(symbols: symbols)
    }

    @Test("C33: a conformer of the one declared member satisfies the protocol")
    func oneMember() async throws {
        let asset = ReferenceClientAsset.stub()
        #expect(try await consume(ScriptedReference(assets: [asset]), symbols: [asset.symbol]) == [asset])
    }

    @Test("C33: CoinMarketCapClient is a ReferenceClient and Sendable")
    func coinMarketCapConforms() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let sendable: any Sendable = cmc
        #expect(sendable is CoinMarketCapClient)
        _ = try await consume(cmc, symbols: [btc])
    }

    @Test("C33: the value declares symbol, name, sector and tier with their declared types", .disabled("Classified 2026-10-04: C33 declares a sector and a tier while L17 makes them readings, and the value hands up CoinMarketCap's rank and tags, unratified, until the owner rules; see validation/step2-ledgers/layer-a-builder.md"))
    func valueShape() {
        let symbol: KeyPath<ReferenceClientAsset, AssetSymbol> = \.symbol
        let name: KeyPath<ReferenceClientAsset, String> = \.name
        let sector: KeyPath<ReferenceClientAsset, String> = \.sector
        let tier: KeyPath<ReferenceClientAsset, Int> = \.tier
        #expect(Set<AnyKeyPath>([symbol, name, sector, tier]).count == 4)
        #expect(Mirror(reflecting: ReferenceClientAsset.stub()).children.count == 4)
    }

    @Test("C33 with C7: the parameterized stub overrides only what it is given; the value is Hashable")
    func stubAndHashable() {
        #expect(ReferenceClientAsset.stub() == ReferenceClientAsset.stub())
        #expect(ReferenceClientAsset.stub(tier: 7).tier == 7)
        #expect(ReferenceClientAsset.stub(tier: 7).symbol == ReferenceClientAsset.stub().symbol)
        #expect(ReferenceClientAsset.stub(tier: 7) != ReferenceClientAsset.stub(tier: 8))
    }

    // MARK: Reading the recorded response

    @Test("C33: the reference hands up the asked symbols with the names the response gave")
    func symbolsAndNames() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let assets = try await cmc.reference(symbols: [btc, eth])
        #expect(Set(assets.map(\.symbol)) == [btc, eth])
        #expect(assets.first { $0.symbol == btc }?.name == "Bitcoin")
        #expect(assets.first { $0.symbol == eth }?.name == "Ethereum")
    }

    @Test("C33: the reference hands up only the symbols asked for")
    func onlyAsked() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let assets = try await cmc.reference(symbols: [btc])
        #expect(assets.map(\.symbol) == [btc])
    }

    @Test("C33: each asset's sector is read from the recorded response, a non-empty text", .disabled("Classified 2026-10-04: C33 declares a sector and a tier while L17 makes them readings, and the value hands up CoinMarketCap's rank and tags, unratified, until the owner rules; see validation/step2-ledgers/layer-a-builder.md"))
    func sectorRead() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let assets = try await cmc.reference(symbols: [btc, eth])
        #expect(assets.count == 2)
        #expect(assets.allSatisfy { !$0.sector.isEmpty })
    }

    // READING: C33 declares `tier: Int` and the API gives `cmc_rank`; the documents are silent on how one becomes the
    // other. This test asserts the tiers keep the ranks' order: rank 1 is not after rank 2.
    @Test("C33 (READING): each asset's tier is read from the recorded rank, keeping the ranks' order")
    func tierRead() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let assets = try await cmc.reference(symbols: [btc, eth])
        let btcTier = try #require(assets.first { $0.symbol == btc }?.tier)
        let ethTier = try #require(assets.first { $0.symbol == eth }?.tier)
        #expect(btcTier <= ethTier)
    }

    // READING: the documents are silent on a symbol the reference does not list. This test asserts it is left out,
    // never invented and never an error.
    @Test("C33 (READING): a symbol the response does not list is left out, never invented")
    func unlistedLeftOut() async throws {
        let (cmc, _) = client([RecordedResponse(body: CoinMarketCapFixtures.listings)])
        let wilma = try AssetSymbol(validating: "WILMA")
        let assets = try await cmc.reference(symbols: [btc, wilma])
        #expect(assets.map(\.symbol) == [btc])
    }

    // MARK: Typed errors (D13, § 8.6)

    @Test("D13: an error envelope with error_code 1002 becomes the client's typed error with that code and message")
    func errorEnvelopeTyped() async {
        let (cmc, _) = client([RecordedResponse(status: 401, body: CoinMarketCapFixtures.apiKeyMissing)])
        let error = await caught { try await cmc.reference(symbols: [btc]) }
        #expect(error != nil)
        #expect(error.flatMap(behavioralExchangeError) == BehavioralExchangeError(code: 1002, message: "API key missing."))
    }

    // READING: D13 asks for FOSFoundation's typed-error pattern; the documents are silent on an envelope with
    // error_code != 0 under HTTP 200. This test asserts the envelope, not the status, decides.
    @Test("D13 (READING): an error envelope under HTTP 200 is still the typed error, never an empty answer")
    func errorEnvelopeUnder200() async {
        let (cmc, _) = client([RecordedResponse(status: 200, body: CoinMarketCapFixtures.invalidKeyWith200)])
        let error = await caught { try await cmc.reference(symbols: [btc]) }
        #expect(error != nil)
        #expect(error.flatMap(behavioralExchangeError) == BehavioralExchangeError(code: 1001, message: "This API Key is invalid."))
    }
}
