// Retrieval_Paging.swift — § 5.1 and layer A: a range larger than one page is paged by cursor, in order, nothing
// dropped or doubled

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("§ 5.1: the retrieval pages by cursor")
struct Retrieval_PagingTests {
    /// 2,500 one-minute bars: more than one Binance page at its default (500) and at its most (1,000)
    let count = 2_500

    // The range runs from the first bar's open to the last bar's close, so no reading of an edge is needed.
    var from: Date { Retrieve.minute(0) }
    var through: Date { Retrieve.minuteClose(count - 1) }

    @Test("§ 5.1: a range larger than one page is fetched in more than one request")
    func moreThanOneRequest() async throws {
        let feed = Retrieve.minuteFeed(count: count)
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(await feed.requests.count > 1)
    }

    @Test("§ 5.1: every bar of the range is kept, once each, in order")
    func nothingDroppedOrDoubled() async throws {
        let store = BehavioralMemoryStore()
        _ = try await Retrieve.make(Retrieve.minuteFeed(count: count), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let kept = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        #expect(kept.count == count)
        #expect(kept.map { ms($0.openTime) } == (0..<count).map { Fx.jan1Ms + Int64($0) * Fx.minuteMs })
    }

    @Test("§ 5.1: the bar at each page boundary appears once")
    func boundaryBarOnce() async throws {
        let store = BehavioralMemoryStore()
        _ = try await Retrieve.make(Retrieve.minuteFeed(count: count), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let openTimes = try await store.bars(market: "BTCUSDT", interval: Fx.minute).map(\.openTime)
        #expect(Set(openTimes).count == openTimes.count)
        for boundary in [499, 500, 999, 1_000, 1_999, 2_000] {
            #expect(openTimes.filter { $0 == Retrieve.minute(boundary) }.count == 1)
        }
    }

    @Test("§ 5.1: the pages are requested in order, each cursor later than the one before")
    func cursorsInOrder() async throws {
        let feed = Retrieve.minuteFeed(count: count)
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let starts = await feed.queries.compactMap { $0["startTime"].flatMap { Int64($0) } }
        let requestCount = await feed.requests.count
        #expect(starts.count == requestCount)
        #expect(zip(starts, starts.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("§ 5.1: every page asks for the same market and interval")
    func sameMarketAndInterval() async throws {
        let feed = Retrieve.minuteFeed(count: count)
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        for query in await feed.queries {
            #expect(query["symbol"] == "BTCUSDT")
            #expect(query["interval"] == "1m")
        }
    }

    @Test("§ 5.1: the kept bars are the feed's bars, value for value, across every page", .disabled("Classified 2026-10-07: asserts prices in the suite's USDT at 6, an asset the caller declares by symbol and exponent, the replaced rule; Binance's client prices in Binance's declared USDT holding at 8, as its exchange information states (design § 2.1, § 5.3); see the identity ledger"))
    func valuesAcrossPages() async throws {
        let store = BehavioralMemoryStore()
        _ = try await Retrieve.make(Retrieve.minuteFeed(count: count), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let kept = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        try #require(kept.count == count)
        for index in [0, 499, 500, 999, 1_000, 2_499] {
            #expect(kept[index].close == syntheticClose(index: index))
            #expect(kept[index].closeTime == Retrieve.minuteClose(index))
        }
    }

    @Test("§ 5.1: the fetch reports the bars it added, the same as what it kept")
    func reportMatchesStore() async throws {
        let store = BehavioralMemoryStore()
        let report = try await Retrieve.make(Retrieve.minuteFeed(count: count), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(report.added == (try await store.bars(market: "BTCUSDT", interval: Fx.minute)))
        #expect(report.gaps.isEmpty)
    }
}
