// L17_FactsNotDecisions.swift — § 7's head with L17 and C33: the public clients hand up facts and decide nothing;
// the sector set, the tier bands, the cuts and the gap rule are the caller's reading

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("L17: facts, not decisions")
struct L17_FactsNotDecisionsTests {
    let btc = try! AssetSymbol(validating: "BTC")
    let eth = try! AssetSymbol(validating: "ETH")
    let usdt = try! AssetSymbol(validating: "USDT")
    let barney = try! AssetSymbol(validating: "BARNEY")

    func reference(_ symbols: [AssetSymbol]) async throws -> [ReferenceClientAsset] {
        try await behavioralCoinMarketCapClient(session: RecordedSession(CoinMarketCapFixtures.listings))
            .reference(symbols: symbols)
    }

    @Test("§ 7: the OHLCV client hands up a bar in which nothing traded; it filters nothing")
    func zeroVolumeHandedUp() async throws {
        let bars = try await Fx.binance(RecordedSession(BinanceFixtures.zeroVolume))
            .ohlcv(market: Fx.btcusdt, interval: Fx.day, from: date(ms: Fx.jan1Ms), through: date(ms: Fx.jan1Ms + 3 * Fx.dayMs - 1))
        #expect(bars.count == 1)
        #expect(bars.first?.volume == Amount.zero(of: Fx.btc))
        #expect(bars.first?.trades == 0)
    }

    @Test("L17 with C33: the reference hands up a stablecoin asked for; excluding it is the caller's")
    func stablecoinHandedUp() async throws {
        #expect(try await reference([usdt]).map(\.symbol) == [usdt])
    }

    @Test("L17 with C33: the reference hands up an asset ranked 4000; a tier cut is the caller's")
    func lowRankHandedUp() async throws {
        #expect(try await reference([barney]).map(\.symbol) == [barney])
    }

    @Test("C33: the reference hands up an asset with no chain platform, which the old aggregator dropped")
    func noPlatformHandedUp() async throws {
        #expect(Set(try await reference([btc, eth]).map(\.symbol)) == [btc, eth])
    }

    // READING: C33 declares `sector: String` and `tier: Int`, and its DocC example shows "Layer 1"; the API gives a
    // rank (`cmc_rank`) and tags. L17's sector set and tier bands are the manifest's, so this test asserts the value
    // carries the rank and a tag exactly as the API gave them, with no bucket name invented by the library.
    @Test("L17 with C33 (READING): the tier is the API's rank and the sector one of the API's tags, as given", .disabled("Classified 2026-10-04: C33 declares a sector and a tier while L17 makes them readings, and the value hands up CoinMarketCap's rank and tags, unratified, until the owner rules; see validation/step2-ledgers/layer-a-builder.md"))
    func rankAndTagAsGiven() async throws {
        let assets = try await reference([btc, eth, usdt, barney])
        let given: [AssetSymbol: (rank: Int, tags: Set<String>)] = [
            btc: (1, ["mineable", "pow", "sha-256", "store-of-value", "layer-1"]),
            eth: (2, ["pos", "smart-contracts", "layer-1", "ethereum-ecosystem"]),
            usdt: (3, ["stablecoin", "asset-backed-stablecoin", "ethereum-ecosystem"]),
            barney: (4000, ["memes"]),
        ]
        #expect(assets.count == 4)
        for asset in assets {
            let fact = try #require(given[asset.symbol])
            #expect(asset.tier == fact.rank)
            #expect(fact.tags.contains(asset.sector))
        }
    }
}
