// Retrieval_Gaps.swift — § 5.1 and layer A: a gap in the feed's answer is detected and kept as a gap, never filled,
// never dropped, never judged (T10's judgement is fosline's)

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("§ 5.1: the retrieval detects gaps and keeps them")
struct Retrieval_GapsTests {
    let market = "BTCUSDT"

    func run(count: Int, missing: Set<Int>, from: Int = 0) async throws -> (OHLCVRetrievalReport, BehavioralMemoryStore) {
        let store = BehavioralMemoryStore()
        let report = try await Retrieve.make(Retrieve.minuteFeed(count: count, missing: missing), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(from), through: Retrieve.minuteClose(count - 1))
        return (report, store)
    }

    @Test("§ 5.1: one missing bar between two closed bars is detected as one gap, bounded by its neighbours")
    func oneMissingBarDetected() async throws {
        let (report, _) = try await run(count: 300, missing: [100])
        #expect(report.gaps == [OHLCVGap(after: Retrieve.minute(99), before: Retrieve.minute(101))])
    }

    @Test("§ 5.1: the detected gap is kept, readable back through the store")
    func gapKept() async throws {
        let (_, store) = try await run(count: 300, missing: [100])
        #expect(try await store.gaps(market: market, interval: Fx.minute)
                == [OHLCVGap(after: Retrieve.minute(99), before: Retrieve.minute(101))])
    }

    @Test("§ 5.1: a gap is never filled; no bar is kept at a missing open time")
    func neverFilled() async throws {
        let (_, store) = try await run(count: 300, missing: [100, 101, 102])
        let kept = try await store.bars(market: market, interval: Fx.minute)
        #expect(kept.count == 297)
        for index in [100, 101, 102] {
            #expect(!kept.contains { $0.openTime == Retrieve.minute(index) })
        }
    }

    @Test("§ 5.1: the bars either side of a gap are kept, nothing dropped")
    func neighboursKept() async throws {
        let (_, store) = try await run(count: 300, missing: [100])
        let openTimes = Set(try await store.bars(market: market, interval: Fx.minute).map(\.openTime))
        #expect(openTimes.contains(Retrieve.minute(99)))
        #expect(openTimes.contains(Retrieve.minute(101)))
        #expect(openTimes.count == 299)
    }

    @Test("§ 5.1 with T10: a long gap is kept and never judged; the fetch does not throw")
    func longGapNotJudged() async throws {
        let missing = Set(100..<400)
        let (report, store) = try await run(count: 600, missing: missing)
        #expect(report.gaps == [OHLCVGap(after: Retrieve.minute(99), before: Retrieve.minute(400))])
        #expect(try await store.bars(market: market, interval: Fx.minute).count == 300)
    }

    @Test("§ 5.1: two gaps are two gaps, in order")
    func twoGaps() async throws {
        let (report, _) = try await run(count: 300, missing: [50, 200, 201])
        #expect(report.gaps == [OHLCVGap(after: Retrieve.minute(49), before: Retrieve.minute(51)),
                                OHLCVGap(after: Retrieve.minute(199), before: Retrieve.minute(202))])
    }

    @Test("§ 5.1: a gap that falls on a page boundary is detected the same as one inside a page")
    func gapAcrossPageBoundary() async throws {
        // Binance's default page is 500 bars and its most 1,000: a gap straddles each boundary
        let (report, _) = try await run(count: 2_500, missing: [499, 500, 501, 999, 1_000, 1_001])
        #expect(report.gaps == [OHLCVGap(after: Retrieve.minute(498), before: Retrieve.minute(502)),
                                OHLCVGap(after: Retrieve.minute(998), before: Retrieve.minute(1_002))])
    }

    // READING: the brief defines a gap as a missing bar between two consecutive closed bars; the documents are silent
    // on a series that begins after `from` (an asset listed later). This test asserts no gap is recorded before the
    // first bar the feed has.
    @Test("§ 5.1 (READING): a series that begins after the range's start records no gap before its first bar")
    func lateStartNoGap() async throws {
        let (report, store) = try await run(count: 300, missing: Set(0..<20))
        #expect(report.gaps.isEmpty)
        #expect(try await store.gaps(market: market, interval: Fx.minute).isEmpty)
        #expect(try await store.bars(market: market, interval: Fx.minute).first?.openTime == Retrieve.minute(20))
    }

    @Test("§ 5.1: a gap on the daily interval is detected at the day's length")
    func dailyGap() async throws {
        let feed = BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.dayMs, count: 10, missing: [4], nowMs: Fx.farFutureMs)
        let report = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.day, from: date(ms: Fx.jan1Ms), through: date(ms: Fx.jan1Ms + 10 * Fx.dayMs - 1))
        #expect(report.gaps == [OHLCVGap(after: date(ms: Fx.jan1Ms + 3 * Fx.dayMs), before: date(ms: Fx.jan1Ms + 5 * Fx.dayMs))])
    }
}
