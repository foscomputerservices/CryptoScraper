// OHLCVHistoryRetrievalTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing

// The retrieval's four duties (§ 5.1, layer A), each against both conformers of the store protocol: the in-memory
// one of these tests and the shipped file one in a temporary directory.

@Suite("The OHLCV retrieval")
struct OHLCVHistoryRetrievalTests {
    @Test(arguments: ContractStoreKind.allCases)
    func aRangeOfTwoPagesIsKeptInOrderWithNothingDroppedOrDoubled(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: binanceRoute)
        try await withRetrieval(kind, session: session) { retrieval in
            let result = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            let kept = try await retrieval.history(Binance.day)

            #expect(result.bars.count == 1200)
            #expect(result.requestCount == 2)
            #expect(kept.bars == result.bars)
            #expect(kept.gaps.isEmpty)

            let opens = kept.bars.map(\.openTime.milliseconds)
            #expect(opens.first == Recorded.rangeStart.milliseconds)
            #expect(opens.last == Recorded.rangeEnd.milliseconds)
            #expect(zip(opens, opens.dropFirst()).allSatisfy { $1 - $0 == 86_400_000 })
            #expect(Set(opens).count == opens.count)

            let raw = Recorded.rawRows(Recorded.page1) + Recorded.rawRows(Recorded.page2)
            #expect(opens == raw.map(\.openTime))
        }
        #expect(session.requests.map { $0.query("startTime") } == ["1502928000000", "1589241600001"])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aGapInTheFeedIsKeptAsAGapAndNeverFilled(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: binanceRoute)
        try await withRetrieval(kind, session: session) { retrieval in
            let result = try await retrieval.retrieve(from: Recorded.gapStart, through: Recorded.gapEnd, interval: Binance.fourHours)
            let kept = try await retrieval.history(Binance.fourHours)

            // 31 open times fit the range; Binance gave 24: the 2018-02-08 outage.
            #expect(kept.bars.count == 24)
            #expect(kept.bars.count == Recorded.rawRows(Recorded.gapPage).count)
            #expect(kept.gaps == [OHLCVHistoryGap(
                lastBarOpenTime: Date(milliseconds: 1_518_048_000_000),      // 2018-02-08 00:00
                nextBarOpenTime: Date(milliseconds: 1_518_163_200_000),      // 2018-02-09 08:00
                missingBarCount: 7
            )])
            #expect(result.gaps == kept.gaps)
            // Nothing invented inside the gap.
            #expect(!kept.bars.contains { (1_518_048_000_001..<1_518_163_200_000).contains($0.openTime.milliseconds) })
        }
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aLimitResponseIsWaitedOutForRetryAfterAndThePageAskedAgain(kind: ContractStoreKind) async throws {
        let session = ReplaySession { request, index in
            index == 0 ? Reply(status: 429, body: Recorded.limitBody, headers: ["Retry-After": "3"]) : binanceRoute(request, index)
        }
        let waits = WaitLog()
        try await withRetrieval(kind, session: session, waits: waits) { retrieval in
            let result = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            #expect(result.bars.count == 1200)
            #expect(result.requestCount == 3)
            #expect(try await retrieval.history(Binance.day).bars.count == 1200)
        }
        #expect(waits.waits == [.seconds(3)])
        #expect(session.requests.map { $0.query("startTime") } == ["1502928000000", "1502928000000", "1589241600001"])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func withoutRetryAfterTheWaitDoubles(kind: ContractStoreKind) async throws {
        let session = ReplaySession { request, index in
            index < 3 ? Reply(status: 429, body: Recorded.limitBody, headers: [:]) : binanceRoute(request, index)
        }
        let waits = WaitLog()
        try await withRetrieval(kind, session: session, waits: waits) { retrieval in
            let result = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            #expect(result.bars.count == 1200)
        }
        #expect(waits.waits == [.seconds(1), .seconds(2), .seconds(4)])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aLimitThatDoesNotLiftIsThrownAndWhatWasKeptStaysKept(kind: ContractStoreKind) async throws {
        let session = ReplaySession { request, index in
            index == 0 ? binanceRoute(request, index) : Reply(status: 418, body: Recorded.limitBody, headers: ["Retry-After": "60"])
        }
        let waits = WaitLog()
        try await withRetrieval(kind, session: session, backoff: OHLCVHistoryBackoff(attempts: 3), waits: waits) { retrieval in
            await #expect(throws: BinanceLimitError.self) {
                try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            }
            let kept = try await retrieval.history(Binance.day)
            #expect(kept.bars.count == 1000)
        }
        #expect(waits.waits == [.seconds(60), .seconds(60)])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aSecondFetchResumesFromTheKeptHistorysLastBar(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: binanceRoute)
        try await withRetrieval(kind, session: session) { retrieval in
            let first = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.page1Last, interval: Binance.day)
            #expect(first.bars.count == 1000)

            let second = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            #expect(second.bars.count == 200)
            #expect(second.bars.first?.openTime.milliseconds == Recorded.page1Last.milliseconds + 86_400_000)

            let kept = try await retrieval.history(Binance.day)
            #expect(kept.bars.count == 1200)
            #expect(kept.bars == first.bars + second.bars)
        }
        // The second call's one request starts a millisecond after the last bar kept.
        #expect(session.requests.map { $0.query("startTime") } == ["1502928000000", "1589241600001"])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aFeedThatRepeatsKeptBarsAddsNothing(kind: ContractStoreKind) async throws {
        // A feed that answers every request with the first page: the second call must keep nothing twice.
        let session = ReplaySession { _, _ in .ok(Recorded.page1) }
        try await withRetrieval(kind, session: session) { retrieval in
            _ = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            let again = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            #expect(again.bars.isEmpty)
            #expect(try await retrieval.history(Binance.day).bars.count == 1000)
        }
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aPageAnsweredOutOfOrderAndTwiceIsKeptOldestFirstOnceEach(kind: ContractStoreKind) async throws {
        // The first recorded page, its rows reversed and its middle row answered twice; then nothing more.
        var rows = try #require(try JSONSerialization.jsonObject(with: Recorded.page1) as? [[Any]])
        rows.reverse()
        rows.insert(rows[rows.count / 2], at: 0)
        let shuffled = try JSONSerialization.data(withJSONObject: rows)
        let session = ReplaySession { _, index in index == 0 ? .ok(shuffled) : .emptyPage }
        try await withRetrieval(kind, session: session) { retrieval in
            let result = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.page1Last, interval: Binance.day)
            let kept = try await retrieval.history(Binance.day)

            #expect(kept.bars.map(\.openTime.milliseconds) == Recorded.rawRows(Recorded.page1).map(\.openTime))
            #expect(result.bars == kept.bars)
            #expect(kept.gaps.isEmpty)
        }
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aGapAcrossTwoCallsIsFoundBetweenTheKeptBarAndTheNextPage(kind: ContractStoreKind) async throws {
        // Keep the gap page's bars up to the outage, then fetch the rest: the gap lies between the two calls.
        let session = ReplaySession(route: binanceRoute)
        try await withRetrieval(kind, session: session) { retrieval in
            _ = try await retrieval.retrieve(from: Recorded.gapStart, through: Date(milliseconds: 1_518_048_000_000), interval: Binance.fourHours)
            let rest = try await retrieval.retrieve(from: Recorded.gapStart, through: Recorded.gapEnd, interval: Binance.fourHours)
            #expect(rest.gaps.map(\.missingBarCount) == [7])
            #expect(try await retrieval.history(Binance.fourHours).gaps.count == 1)
        }
    }
}

@Suite("The file store")
struct OHLCVHistoryFileStoreTests {
    @Test func theFileIsJSONLinesNamedByMarketAndInterval() async throws {
        let directory = temporaryDirectory()
        let session = ReplaySession(route: binanceRoute)
        try await withRetrieval(.file, session: session, directory: directory) { retrieval in
            _ = try await retrieval.retrieve(from: Recorded.gapStart, through: Recorded.gapEnd, interval: Binance.fourHours)
        }
        let file = directory.appendingPathComponent("BTCUSDT_4h.jsonl")
        #expect(OHLCVHistoryFileStore<BinanceMarketName>(directory: directory).fileURL(market: Binance.btcusdt, interval: Binance.fourHours) == file)

        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 25)
        #expect(lines.filter { $0.hasPrefix(#"{"gap":"#) }.count == 1)
        #expect(lines.filter { $0.hasPrefix(#"{"bar":"#) }.count == 24)
        // The gap's line sits just before the first bar after it.
        let gapIndex = try #require(lines.firstIndex { $0.hasPrefix(#"{"gap":"#) })
        #expect(lines[gapIndex + 1].contains("2018-02-09T08:00:00.000Z"))
    }

    @Test func aFreshStoreReadsBackWhatAnotherKept() async throws {
        let directory = temporaryDirectory()
        let session = ReplaySession(route: binanceRoute)
        let written = try await withRetrieval(.file, session: session, directory: directory) { retrieval in
            _ = try await retrieval.retrieve(from: Recorded.gapStart, through: Recorded.gapEnd, interval: Binance.fourHours)
            return try await retrieval.history(Binance.fourHours)
        }
        let reread = try await OHLCVHistoryFileStore<BinanceMarketName>(directory: directory).history(market: Binance.btcusdt, interval: Binance.fourHours)
        #expect(reread == written)
        let last = try await OHLCVHistoryFileStore<BinanceMarketName>(directory: directory).lastBar(market: Binance.btcusdt, interval: Binance.fourHours)
        #expect(last == written.bars.last)
    }

    @Test func aTornLineIsAnErrorNeverSkipped() async throws {
        let directory = temporaryDirectory()
        let file = directory.appendingPathComponent("BTCUSDT_1d.jsonl")
        try Data(#"{"bar":{"openTime":"#.utf8).write(to: file)
        await #expect(throws: (any Error).self) {
            try await OHLCVHistoryFileStore<BinanceMarketName>(directory: directory).history(market: Binance.btcusdt, interval: Binance.day)
        }
    }

    @Test func aMarketsDescriptionIsEscapedInTheFileName() {
        struct Odd: Hashable, Sendable, CustomStringConvertible { let description = "A/B c" }
        let url = OHLCVHistoryFileStore<Odd>(directory: URL(fileURLWithPath: "/tmp")).fileURL(market: Odd(), interval: .init(count: 15, unit: .minute))
        #expect(url.lastPathComponent == "A%2FB%20c_15m.jsonl")
    }

    @Test func nothingKeptIsAnEmptyHistory() async throws {
        let store = OHLCVHistoryFileStore<BinanceMarketName>(directory: temporaryDirectory())
        #expect(try await store.history(market: Binance.btcusdt, interval: Binance.day) == OHLCVHistory(bars: [], gaps: []))
        #expect(try await store.lastBar(market: Binance.btcusdt, interval: Binance.day) == nil)
    }
}

@Suite("The backoff")
struct OHLCVHistoryBackoffTests {
    @Test func retryAfterWinsAndTheDoublingStopsAtTheLongestWait() {
        let backoff = OHLCVHistoryBackoff(attempts: 10, firstWait: .seconds(1), longestWait: .seconds(10))
        #expect(backoff.wait(afterLimit: 1, retryAfter: .seconds(30)) == .seconds(30))
        #expect((1...6).map { backoff.wait(afterLimit: $0, retryAfter: nil) } == [1, 2, 4, 8, 10, 10].map { .seconds($0) })
    }
}
