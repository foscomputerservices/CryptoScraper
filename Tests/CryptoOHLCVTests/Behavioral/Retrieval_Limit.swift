// Retrieval_Limit.swift — § 5.1 and layer A: a limit response backs off for the Retry-After it was given, then
// resumes from the same cursor

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("§ 5.1: the retrieval backs off on a limit")
struct Retrieval_LimitTests {
    let count = 2_500
    var from: Date { Retrieve.minute(0) }
    var through: Date { Retrieve.minuteClose(count - 1) }

    @Test("§ 5.1: a 429 with Retry-After 3 is slept for exactly 3 seconds, once")
    func sleepsForRetryAfter() async throws {
        let sleep = SleepRecorder()
        let feed = Retrieve.minuteFeed(count: count, limited: [0: "3"])
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore(), sleep: sleep)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(await sleep.asked == [.seconds(3)])
    }

    @Test("§ 5.1: after the back-off the same request is sent again, from the same cursor")
    func resumesSameCursor() async throws {
        let feed = Retrieve.minuteFeed(count: count, limited: [0: "3"])
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let queries = await feed.queries
        try #require(queries.count >= 2)
        #expect(queries[1]["startTime"] == queries[0]["startTime"])
        #expect(queries[1]["endTime"] == queries[0]["endTime"])
    }

    @Test("§ 5.1: a limit in the middle of paging resumes from that page's cursor, nothing dropped or doubled")
    func limitMidPaging() async throws {
        let store = BehavioralMemoryStore()
        let feed = Retrieve.minuteFeed(count: count, limited: [1: "2"])
        _ = try await Retrieve.make(feed, store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let queries = await feed.queries
        try #require(queries.count >= 3)
        #expect(queries[2]["startTime"] == queries[1]["startTime"])
        let openTimes = try await store.bars(market: "BTCUSDT", interval: Fx.minute).map(\.openTime)
        #expect(openTimes.count == count)
        #expect(Set(openTimes).count == count)
    }

    @Test("§ 5.1: two limits in a row are two back-offs, then the fetch completes")
    func twoLimits() async throws {
        let sleep = SleepRecorder()
        let store = BehavioralMemoryStore()
        let feed = Retrieve.minuteFeed(count: count, limited: [0: "1", 1: "5"])
        _ = try await Retrieve.make(feed, store: store, sleep: sleep)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(await sleep.asked == [.seconds(1), .seconds(5)])
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).count == count)
    }

    @Test("§ 5.1: a limit is not an error to the caller; the fetch completes and keeps every bar")
    func limitNotThrown() async throws {
        let store = BehavioralMemoryStore()
        let report = try await Retrieve.make(Retrieve.minuteFeed(count: count, limited: [0: "3"]), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(report.added.count == count)
    }

    @Test("§ 5.1: with no limit, the retrieval never sleeps")
    func noLimitNoSleep() async throws {
        let sleep = SleepRecorder()
        _ = try await Retrieve.make(Retrieve.minuteFeed(count: count), store: BehavioralMemoryStore(), sleep: sleep)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        #expect(await sleep.asked.isEmpty)
    }

    // READING: the brief says back off "for the Retry-After it was given (or a documented default)"; the documents do
    // not give the default's value. This test asserts one positive back-off and a resumed fetch, not the value.
    @Test("§ 5.1 (READING): a 429 without Retry-After backs off once for a positive default, then resumes")
    func defaultBackOff() async throws {
        let sleep = SleepRecorder()
        let store = BehavioralMemoryStore()
        let feed = Retrieve.minuteFeed(count: count, limited: [0: String?.none])
        _ = try await Retrieve.make(feed, store: store, sleep: sleep)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: from, through: through)
        let asked = await sleep.asked
        #expect(asked.count == 1)
        #expect(asked.allSatisfy { $0 > .zero })
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).count == count)
    }
}
