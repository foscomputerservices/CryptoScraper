// T8_T69_ClosedBarsOnly.swift — T8 and T69 with C32: ohlcv hands up closed bars only; the still-open bar never
// appears among them, and the retrieval never keeps it

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("T8, T69: closed bars only")
struct T8_T69_ClosedBarsOnlyTests {
    let jan1 = date(ms: Fx.jan1Ms)
    /// Through the end of 2024-01-03, the still-open day at now = 2024-01-03T12:00Z
    let through = date(ms: Fx.jan1Ms + 3 * Fx.dayMs - 1)

    @Test("T8: ohlcv leaves out the still-open bar the feed sent last")
    func openBarLeftOut() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.withOpen), nowMs: BinanceFixtures.withOpenNowMs)
        let bars = try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: through)
        #expect(bars.map { ms($0.openTime) } == [1_704_067_200_000, 1_704_153_600_000])
    }

    @Test("T8: every bar ohlcv hands up is closed")
    func everyBarClosed() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.withOpen), nowMs: BinanceFixtures.withOpenNowMs)
        let bars = try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: through)
        #expect(!bars.isEmpty)
        #expect(bars.allSatisfy(\.isClosed))
        #expect(bars.allSatisfy { ms($0.closeTime) < BinanceFixtures.withOpenNowMs })
    }

    @Test("T8 with C32: the bar openOHLCV hands up is never among ohlcv's bars")
    func openNotAmongClosed() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.withOpen), nowMs: BinanceFixtures.withOpenNowMs)
        let bars = try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: through)
        let open = try #require(try await client.openOHLCV(market: Fx.btcusdt, interval: Fx.day))
        #expect(!bars.contains { $0.openTime == open.openTime })
    }

    @Test("T8 with T9: the retrieval never keeps the still-open bar")
    func retrievalKeepsClosedOnly() async throws {
        // 100 minute bars; now falls inside bar 99, so 0…98 are closed
        let nowMs = Fx.jan1Ms + 99 * Fx.minuteMs + 30_000
        let feed = BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.minuteMs, count: 100, nowMs: nowMs)
        let store = BehavioralMemoryStore()
        let report = try await Retrieve.make(feed, store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(99))
        let kept = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        #expect(kept.count == 99)
        #expect(kept.allSatisfy(\.isClosed))
        #expect(!kept.contains { $0.openTime == Retrieve.minute(99) })
        #expect(!report.added.contains { $0.openTime == Retrieve.minute(99) })
    }

    @Test("T8 with T9: the still-open bar is not recorded as a gap either")
    func openBarNoGap() async throws {
        let nowMs = Fx.jan1Ms + 99 * Fx.minuteMs + 30_000
        let feed = BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.minuteMs, count: 100, nowMs: nowMs)
        let report = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(99))
        #expect(report.gaps.isEmpty)
    }
}
