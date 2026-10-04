// T87_UTCInstants.swift — T87 with C32 and D16: times are UTC instants, and a bar's open and close times are the
// feed's exactly, never rounded to a local calendar

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("T87: the feed's instants, exactly", .serialized)
struct T87_UTCInstantsTests {
    let jan1 = date(ms: Fx.jan1Ms)
    let jan3End = date(ms: Fx.jan1Ms + 3 * Fx.dayMs - 1)

    @Test("T87: a bar's openTime and closeTime are the feed's milliseconds exactly")
    func feedTimesExact() async throws {
        let bars = try await Fx.binance(RecordedSession(BinanceFixtures.dailyClosed))
            .ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End)
        #expect(bars.map { ms($0.openTime) } == [1_704_067_200_000, 1_704_153_600_000])
        #expect(bars.map { ms($0.closeTime) } == [1_704_153_599_999, 1_704_239_999_999])
    }

    @Test("T87: the daily bar opens at 00:00 UTC as the feed gave it")
    func dailyAtMidnightUTC() async throws {
        let bar = try #require(try await Fx.binance(RecordedSession(BinanceFixtures.dailyClosed))
            .ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End).first)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: bar.openTime)
        #expect([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second] == [2024, 1, 1, 0, 0, 0])
    }

    @Test("T87: under a process time zone far from UTC, the bar's instants are unchanged")
    func localTimeZoneIgnored() async throws {
        let saved = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Pacific/Auckland")!
        defer { NSTimeZone.default = saved }
        let bars = try await Fx.binance(RecordedSession(BinanceFixtures.dailyClosed))
            .ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End)
        #expect(bars.map { ms($0.openTime) } == [1_704_067_200_000, 1_704_153_600_000])
        #expect(bars.map { ms($0.closeTime) } == [1_704_153_599_999, 1_704_239_999_999])
    }

    @Test("T87 with D16: the weekly bar's Monday 00:00 UTC open and Sunday close are the feed's, unrounded")
    func weeklyUnrounded() async throws {
        let bar = try #require(try await Fx.binance(RecordedSession(BinanceFixtures.weekly))
            .ohlcv(market: Fx.btcusdt, interval: Fx.week, from: jan1, through: date(ms: Fx.jan1Ms + Fx.weekMs - 1)).first)
        #expect(ms(bar.openTime) == 1_704_067_200_000)
        #expect(ms(bar.closeTime) == 1_704_671_999_999)
    }

    @Test("T87 with OQ-S20: the feed's instants survive the file store to the millisecond")
    func instantsSurviveFileStore() async throws {
        let directory = freshDirectory()
        let feed = BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.dayMs, count: 5, nowMs: Fx.farFutureMs)
        _ = try await Retrieve.make(feed, store: try FileOHLCVStore(directory: directory))
            .fetch(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: date(ms: Fx.jan1Ms + 5 * Fx.dayMs - 1))
        let kept = try await FileOHLCVStore(directory: directory).bars(market: "BTCUSDT", interval: Fx.day)
        #expect(kept.map { ms($0.openTime) } == (0..<5).map { Fx.jan1Ms + Int64($0) * Fx.dayMs })
        #expect(kept.map { ms($0.closeTime) } == (1...5).map { Fx.jan1Ms + Int64($0) * Fx.dayMs - 1 })
    }
}
