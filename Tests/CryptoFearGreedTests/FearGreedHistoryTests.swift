// FearGreedHistoryTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoFearGreed
import FOSFoundation
import Foundation
import Testing

// The day's one serialization, the file store, and the retrieval that resumes after the last day kept, each
// retrieval test against both conformers of the store protocol: the in-memory one of these tests and the shipped file
// one in a temporary directory.

@Suite("Fear and Greed day")
struct FearGreedDayTests {
    @Test func theStubIsTheReservedFake() {
        let stub = FearGreedDay.stub()
        #expect(stub.timestamp == Date(timeIntervalSince1970: 42 * 86_400))
        #expect(stub.value == 42)
        #expect(stub.classification == "Stub 42")
        #expect(stub == .stub(value: 42))
        #expect(FearGreedDay.stub(value: 8, classification: "Extreme Fear").value == 8)
        #expect(FearGreedDay.stub(value: 8, classification: "Extreme Fear").classification == "Extreme Fear")
    }

    @Test func theDayRoundTripsThroughFOSFoundationsJSON() throws {
        let day = FearGreedDay(timestamp: Recorded.firstDay, value: 30, classification: "Fear")
        let text = try day.toJSON()
        let back: FearGreedDay = try text.fromJSON()

        #expect(back == day)
        #expect(text.contains("2018-02-01T00:00:00.000Z"))
    }
}

@Suite("Fear and Greed file store")
struct FearGreedHistoryFileStoreTests {
    private let days = (0..<3).map { FearGreedDay(timestamp: day(17563 + $0), value: 30 + $0, classification: "Fear") }

    @Test func nothingKeptIsNoDayAndNoFile() async throws {
        let file = temporaryFile()
        let store = FearGreedHistoryFileStore(file: file)
        #expect(try await store.lastDay() == nil)
        #expect(try await store.history().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func theFileIsOneDayPerLineInTheOneSerialization() async throws {
        let file = temporaryFile()
        try await FearGreedHistoryFileStore(file: file).append(days)
        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")

        #expect(lines.count == 3)
        #expect(try lines.map { line -> FearGreedDay in try String(line).fromJSON() } == days)
        // A time is UTC text to the millisecond.
        #expect(lines[0].contains("\"2018-02-01T00:00:00.000Z\""))
        #expect(lines[2].contains("\"2018-02-03T00:00:00.000Z\""))
    }

    @Test func aSecondStoreReadsWhatTheFirstWrote() async throws {
        let file = temporaryFile()
        try await FearGreedHistoryFileStore(file: file).append(days)
        let reader = FearGreedHistoryFileStore(file: file)

        #expect(try await reader.history() == days)
        #expect(try await reader.lastDay() == days.last)
    }

    @Test func anAppendAddsLinesAndNeverRewritesOne() async throws {
        let file = temporaryFile()
        let store = FearGreedHistoryFileStore(file: file)
        try await store.append(Array(days.prefix(2)))
        let before = try Data(contentsOf: file)
        try await store.append(Array(days.suffix(1)))
        let after = try Data(contentsOf: file)

        #expect(after.prefix(before.count) == before)
        #expect(after.count > before.count)
        #expect(try await store.history() == days)
        #expect(try await FearGreedHistoryFileStore(file: file).history() == days)
    }

    @Test func aLineThatDoesNotDecodeIsAnErrorNeverSkipped() async throws {
        let file = temporaryFile()
        try await FearGreedHistoryFileStore(file: file).append(days)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"timestamp":"2018-02-04T00:00:00.000Z","val"#.utf8))
        try handle.close()

        await #expect(throws: (any Error).self) {
            try await FearGreedHistoryFileStore(file: file).history()
        }
    }
}

@Suite("Fear and Greed retrieval")
struct FearGreedHistoryRetrievalTests {
    @Test(arguments: ContractStoreKind.allCases)
    func withNothingKeptTheWholeHistoryIsAskedAndKept(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let store = makeStore(kind)
        let kept = try await retrieve(into: store, session: session)

        #expect(kept.count == 3166)
        #expect(kept.first?.timestamp == Recorded.firstDay)
        #expect(kept.last?.timestamp == Recorded.lastFinalDay)
        #expect(try await store.history() == kept)
        #expect(session.requests.map { $0.query("limit") } == ["0"])
    }

    @Test(arguments: ContractStoreKind.allCases)
    func theRetrievalResumesAfterTheLastDayKept(kind: ContractStoreKind) async throws {
        let whole = try await client(ReplaySession(route: alternativeMeRoute)).fearGreedHistory()
        // Kept through 2026-10-01; the recording's clock is 2026-10-07 14:56 UTC.
        let through = try #require(whole.firstIndex { $0.timestamp == day(20727) })
        let store = makeStore(kind)
        try await store.append(Array(whole[...through]))

        let session = ReplaySession(route: alternativeMeRoute)
        let kept = try await retrieve(into: store, session: session)

        // The days since the last day kept: 2026-10-07 back to 2026-10-01, seven rows; the in-progress day dropped and
        // the day already kept never kept again.
        #expect(session.requests.map { $0.query("limit") } == ["7"])
        #expect(kept == Array(whole[(through + 1)...]))
        #expect(kept.map(\.timestamp) == (20728...20732).map(day))
        #expect(try await store.history() == whole)
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aSecondRetrievalKeepsNothingAlreadyKept(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let store = makeStore(kind)
        _ = try await retrieve(into: store, session: session)
        let again = try await retrieve(into: store, session: session)

        #expect(again.isEmpty)
        #expect(session.requests.map { $0.query("limit") } == ["0", "2"])
        let stamps = try await store.history().map(\.timestamp)
        #expect(stamps.count == 3166)
        #expect(Set(stamps).count == stamps.count)
    }

    @Test(arguments: ContractStoreKind.allCases)
    func aDayNotAfterTheLastKeptIsNeverKept(kind: ContractStoreKind) async throws {
        // The publisher answers a day at or before the last day kept, and one after it: only the one after is kept.
        let store = makeStore(kind)
        let last = FearGreedDay(timestamp: day(20730), value: 70, classification: "Greed")
        try await store.append([last])
        let rows: [[String: Any]] = [
            ["value": "73", "value_classification": "Greed", "timestamp": "1791244800"],     // 2026-10-06, after the last: kept
            ["value": "71", "value_classification": "Greed", "timestamp": "1791072000"],     // 2026-10-04, the last day kept
            ["value": "65", "value_classification": "Greed", "timestamp": "1790985600"]      // 2026-10-03, before it
        ]
        let body = Recorded.response(Recorded.whole, rows: rows)
        let session = ReplaySession { _ in .ok(body) }
        let kept = try await retrieve(into: store, session: session)

        #expect(kept.map(\.timestamp) == [day(20732)])
        #expect(try await store.history().map(\.timestamp) == [day(20730), day(20732)])
        #expect(try await store.history().first == last)
    }

    // A retrieval over the recorded client, its clock the recording's, into the store whatever its type.
    private func retrieve(into store: some FearGreedHistoryStore, session: ReplaySession) async throws -> [FearGreedDay] {
        try await FearGreedHistoryRetrieval(client: client(session), store: store, now: { Recorded.recordedAt }).retrieve()
    }
}
