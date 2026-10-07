// FG1 — The public Fear and Greed client, its store, its file store and its retrieval.
// Projected from plans/2026-10-06-sentiment-source-design.md § 1: "A client that hands up the Fear and Greed index as
// its publisher publishes it: a day, a value from 0 to 100, the publisher's word. It decides nothing." and "A day the
// publisher is still updating is never handed up." and the store's, file store's and retrieval's DocC. And "Its proof
// (AR13). A recorded `limit=0` response decodes to the 3,132 days of the POC's vector, day for day and value for value,
// with the still-updating day dropped."
// Recorded answers only; never a live call.

import CryptoFearGreed   // invented: the module name — § 1 says "a new library of CryptoScraper beside `CryptoOHLCV`" and names none
import FOSFoundation
import Foundation
import Synchronization
import Testing

/// A publisher scripted from days in hand, so the retrieval is tested against the documented contract alone
private final class ScriptedPublisher: FearGreedClient {
    let days: [FearGreedDay]
    let asked = Mutex<[String]>([])
    init(_ days: [FearGreedDay]) { self.days = days }

    func fearGreedHistory() async throws -> [FearGreedDay] {
        asked.withLock { $0.append("history") }
        return days
    }

    func fearGreed(lastDays count: Int) async throws -> [FearGreedDay] {
        asked.withLock { $0.append("last \(count)") }
        return Array(days.suffix(count))
    }
}

private func day(_ n: Int, value: Int = 42) -> FearGreedDay {
    .stub(timestamp: Date(timeIntervalSince1970: TimeInterval(n) * 86_400), value: value)
}

private func freshFile() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "fg1-\(UUID().uuidString).jsonl")
}

@Suite("FG1 FearGreedDay")
struct FG1_FearGreedDayTests {
    // "public static func stub() -> Self { .stub(value: 42) }" and "Day 42 after the epoch, the value 42, the word \"Stub 42\""
    @Test func stubIsDayFortyTwo() {
        let stub = FearGreedDay.stub()
        #expect(stub.timestamp == Date(timeIntervalSince1970: 42 * 86_400))
        #expect(stub.value == 42)
        #expect(stub.classification == "Stub 42")
    }

    // "let fear = FearGreedDay.stub(value: 8, classification: \"Extreme Fear\")"
    @Test func stubOverrideKeepsTheRest() {
        let fear = FearGreedDay.stub(value: 8, classification: "Extreme Fear")
        #expect(fear.value == 8)
        #expect(fear.classification == "Extreme Fear")
        #expect(fear.timestamp == FearGreedDay.stub().timestamp)
    }

    // "Encodes with its synthesized shape, the one serialization ``FearGreedHistoryFileStore`` writes."
    @Test func roundTrips() throws {
        let fear = FearGreedDay.stub(value: 8, classification: "Extreme Fear")
        let back: FearGreedDay = try fear.toJSON().fromJSON()
        #expect(back == fear)
    }

    // "The publisher's own word for the value, verbatim and in its own case"
    @Test func classificationKeepsItsCase() throws {
        let lower = FearGreedDay.stub(classification: "extreme fear")
        let back: FearGreedDay = try lower.toJSON().fromJSON()
        #expect(back.classification == "extreme fear")
    }
}

@Suite("FG1 AlternativeMeFearGreedClient")
struct FG1_AlternativeMeClientTests {
    // invented: RecordedAlternativeMe.session(answering:) — "a test passes a recorded one" (the session parameter); the loader is not declared
    private func client(_ recording: String) -> AlternativeMeFearGreedClient {
        AlternativeMeFearGreedClient(session: RecordedAlternativeMe.session(answering: recording))
    }

    // "A recorded `limit=0` response decodes to the 3,132 days of the POC's vector, day for day and value for value"
    @Test(.disabled("Classified 2026-10-07: no recording of the POC's vector of 3,132 days in this public package (it lives in fosline); the recording of 2026-10-07 holds 3,166 final days; see the identity ledger")) func wholeHistoryIsThePOCsVector() async throws {
        let all = try await client("fng-limit-0").fearGreedHistory()
        // invented: POCVector.fearGreedDays() — the POC's vector of 3,132 days as (timestamp, value); its loader is not declared
        let vector = try POCVector.fearGreedDays()
        #expect(all.count == 3_132)
        #expect(all.map(\.timestamp) == vector.map(\.timestamp))
        #expect(all.map(\.value) == vector.map(\.value))
    }

    // "all.first?.timestamp         // 2018-02-01 UTC"
    @Test func historyStartsOnTheFirstOfFebruary2018() async throws {
        let all = try await client("fng-limit-0").fearGreedHistory()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let first = try #require(all.first)
        #expect(utc.dateComponents([.year, .month, .day], from: first.timestamp) == DateComponents(year: 2018, month: 2, day: 1))
    }

    // "Every day the publisher has published and will not update again, oldest first"
    @Test func historyIsOldestFirst() async throws {
        let all = try await client("fng-limit-0").fearGreedHistory()
        #expect(all.map(\.timestamp) == all.map(\.timestamp).sorted())
    }

    // "The day still being updated, the one that carries `time_until_update`, is dropped."
    @Test(.disabled("Classified 2026-10-07: no recording fng-limit-2 (two days, the latest still updating); see the identity ledger")) func stillUpdatingDayIsDropped() async throws {
        // the recording "fng-limit-2" carries two days, the latest with `time_until_update`
        let recent = try await client("fng-limit-2").fearGreed(lastDays: 2)
        #expect(recent.count == 1)
    }

    // "The index, 0 to 100, decoded exactly from the publisher's text"
    @Test func valuesAreZeroToOneHundred() async throws {
        for day in try await client("fng-limit-0").fearGreedHistory() {
            #expect((0...100).contains(day.value))
        }
    }

    // "A `value` ... whose text is not a whole number throws ``AlternativeMeFearGreedError``" — malformedValue
    @Test(.disabled("Classified 2026-10-07: no recording fng-malformed-value (a value of 4.2); see the identity ledger")) func malformedValueThrows() async {
        // the recording "fng-malformed-value" carries `"value": "4.2"`
        await #expect(throws: AlternativeMeFearGreedError.malformedValue("4.2")) {
            _ = try await client("fng-malformed-value").fearGreedHistory()
        }
    }

    // "A `value` that is not a whole number from 0 to 100" — out of range is malformed too
    @Test(.disabled("Classified 2026-10-07: no recording fng-value-101 (a value of 101); see the identity ledger")) func outOfRangeValueThrows() async {
        // the recording "fng-value-101" carries `"value": "101"`
        await #expect(throws: AlternativeMeFearGreedError.malformedValue("101")) {
            _ = try await client("fng-value-101").fearGreedHistory()
        }
    }

    // "A `timestamp` that is not whole Unix seconds" — malformedTimestamp
    @Test(.disabled("Classified 2026-10-07: no recording fng-malformed-timestamp (a timestamp of yesterday); see the identity ledger")) func malformedTimestampThrows() async {
        // the recording "fng-malformed-timestamp" carries `"timestamp": "yesterday"`
        await #expect(throws: AlternativeMeFearGreedError.malformedTimestamp("yesterday")) {
            _ = try await client("fng-malformed-timestamp").fearGreedHistory()
        }
    }

    // "asking `limit` and `format=json`: `limit=0` is the whole history"
    @Test func historyAsksLimitZero() async throws {
        _ = try await client("fng-limit-0").fearGreedHistory()
        // invented: RecordedAlternativeMe.lastRequestURL — the recorded session's view of what was asked
        let url = try #require(RecordedAlternativeMe.lastRequestURL)
        #expect(url.path().hasSuffix("/fng/"))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "limit", value: "0")))
        #expect(query.contains(URLQueryItem(name: "format", value: "json")))
    }

    // "The final days among the publisher's latest `count`" — asks that count
    @Test func lastDaysAsksTheCount() async throws {
        _ = try await client("fng-limit-30").fearGreed(lastDays: 30)
        let url = try #require(RecordedAlternativeMe.lastRequestURL)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "limit", value: "30")))
    }

    // "The final days among the publisher's latest `count`, oldest first" — never more than asked
    @Test func lastDaysIsAtMostTheCount() async throws {
        let recent = try await client("fng-limit-30").fearGreed(lastDays: 30)
        #expect(recent.count <= 30)
        #expect(recent.map(\.timestamp) == recent.map(\.timestamp).sorted())
    }
}

@Suite("FG1 FearGreedHistoryFileStore")
struct FG1_FileStoreTests {
    // "The last day kept, or `nil` when none is kept"
    @Test func emptyStoreHasNoLastDay() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        #expect(try await store.lastDay() == nil)
        #expect(try await store.history().isEmpty)
    }

    // "The file the days are in, created on the first append"
    @Test func fileIsCreatedOnTheFirstAppend() async throws {
        let file = freshFile()
        let store = FearGreedHistoryFileStore(file: file)
        #expect(!FileManager.default.fileExists(atPath: file.path()))
        try await store.append([day(42)])
        #expect(FileManager.default.fileExists(atPath: file.path()))
    }

    // "Everything kept, in the order kept"
    @Test func historyIsInTheOrderKept() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await store.append([day(42), day(43)])
        try await store.append([day(44)])
        #expect(try await store.history() == [day(42), day(43), day(44)])
        #expect(try await store.lastDay() == day(44))
    }

    // "JSON Lines: one ``FearGreedDay`` per line, in the order kept"
    @Test func oneDayPerLine() async throws {
        let file = freshFile()
        let store = FearGreedHistoryFileStore(file: file)
        try await store.append([day(42), day(43), day(44)])
        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3)
        let first: FearGreedDay = try String(lines[0]).fromJSON()
        #expect(first == day(42))
    }

    // "An append adds lines at the end and never rewrites one."
    @Test func appendNeverRewritesALine() async throws {
        let file = freshFile()
        let store = FearGreedHistoryFileStore(file: file)
        try await store.append([day(42)])
        let before = try String(contentsOf: file, encoding: .utf8)
        try await store.append([day(43)])
        let after = try String(contentsOf: file, encoding: .utf8)
        #expect(after.hasPrefix(before))
    }

    // "A line that does not decode is an error and never skipped."
    @Test func undecodableLineIsAnError() async throws {
        let file = freshFile()
        let good = try day(42).toJSON()
        try (good + "\nnot a day\n").write(to: file, atomically: true, encoding: .utf8)
        let store = FearGreedHistoryFileStore(file: file)
        await #expect(throws: (any Error).self) { _ = try await store.history() }
    }

    // "A store keeps what it is handed, in the order handed, and never fills, judges or reorders."
    @Test func storeNeverReorders() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await store.append([day(44), day(42)])
        #expect(try await store.history() == [day(44), day(42)])
    }

    // "One store per file per process: the store reads the file once and keeps it in memory after."
    @Test(.disabled("Classified 2026-10-07: its untyped day(42).toJSON() resolves to the target's own Fixtures.swift day(_:) -> Date, not the file's private day(_:value:) -> FearGreedDay, so it writes a date where a day is meant; no wiring reaches a name the target already declares; see the identity ledger")) func storeReadsTheFileOnce() async throws {
        let file = freshFile()
        try (try day(42).toJSON() + "\n").write(to: file, atomically: true, encoding: .utf8)
        let store = FearGreedHistoryFileStore(file: file)
        #expect(try await store.history() == [day(42)])
        // a line written behind the store's back is not read again
        try (try day(42).toJSON() + "\n" + day(43).toJSON() + "\n").write(to: file, atomically: true, encoding: .utf8)
        #expect(try await store.history() == [day(42)])
    }

    // "through FOSFoundation's `toJSON()`, so a time is UTC text to the millisecond" — a reopened file reads the same days
    @Test func reopenedFileReadsTheSameDays() async throws {
        let file = freshFile()
        let millis = FearGreedDay.stub(timestamp: Date(timeIntervalSince1970: 42 * 86_400 + 0.042))
        try await FearGreedHistoryFileStore(file: file).append([millis, day(43)])
        #expect(try await FearGreedHistoryFileStore(file: file).history() == [millis, day(43)])
    }
}

@Suite("FG1 FearGreedHistoryRetrieval")
struct FG1_RetrievalTests {
    // "With nothing kept it asks for the whole history"
    @Test func nothingKeptAsksForTheWholeHistory() async throws {
        let publisher = ScriptedPublisher([day(42), day(43), day(44)])
        let store = FearGreedHistoryFileStore(file: freshFile())
        let kept = try await FearGreedHistoryRetrieval(client: publisher, store: store).retrieve()
        #expect(publisher.asked.withLock { $0 } == ["history"])
        #expect(kept == [day(42), day(43), day(44)])
        #expect(try await store.history() == [day(42), day(43), day(44)])
    }

    // "after that, for the days since the last day kept, and keeps only those after it"
    @Test func afterThatKeepsOnlyTheDaysAfterTheLast() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await store.append([day(42), day(43)])
        let publisher = ScriptedPublisher([day(41), day(42), day(43), day(44), day(45)])
        let now = Date(timeIntervalSince1970: 45 * 86_400 + 3_600)
        let kept = try await FearGreedHistoryRetrieval(client: publisher, store: store, now: { now }).retrieve()
        #expect(kept == [day(44), day(45)])
        #expect(try await store.history() == [day(42), day(43), day(44), day(45)])
    }

    // "for the days since the last day kept" — it asks a count back, not the whole history
    @Test func afterThatAsksTheDaysSince() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await store.append([day(42)])
        let publisher = ScriptedPublisher([day(42), day(43), day(44)])
        let now = Date(timeIntervalSince1970: 44 * 86_400 + 3_600)
        _ = try await FearGreedHistoryRetrieval(client: publisher, store: store, now: { now }).retrieve()
        let asked = publisher.asked.withLock { $0 }
        #expect(!asked.contains("history"))
        #expect(asked.allSatisfy { $0.hasPrefix("last ") })
    }

    // "A hole the publisher left is kept as a hole, never filled."
    @Test func aHoleIsKeptAsAHole() async throws {
        let publisher = ScriptedPublisher([day(42), day(44)])
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await FearGreedHistoryRetrieval(client: publisher, store: store).retrieve()
        #expect(try await store.history() == [day(42), day(44)])
    }

    // "The days this call kept" — nothing new keeps nothing
    @Test func nothingNewKeepsNothing() async throws {
        let store = FearGreedHistoryFileStore(file: freshFile())
        try await store.append([day(42), day(43)])
        let publisher = ScriptedPublisher([day(42), day(43)])
        let now = Date(timeIntervalSince1970: 43 * 86_400 + 3_600)
        let kept = try await FearGreedHistoryRetrieval(client: publisher, store: store, now: { now }).retrieve()
        #expect(kept.isEmpty)
        #expect(try await store.history() == [day(42), day(43)])
    }

    // "Grows a kept Fear and Greed history to the publisher's last final day" — run twice, the second keeps nothing
    @Test func secondRunKeepsNothing() async throws {
        let publisher = ScriptedPublisher([day(42), day(43)])
        let store = FearGreedHistoryFileStore(file: freshFile())
        let now = Date(timeIntervalSince1970: 43 * 86_400 + 3_600)
        let retrieval = FearGreedHistoryRetrieval(client: publisher, store: store, now: { now })
        try await retrieval.retrieve()
        #expect(try await retrieval.retrieve().isEmpty)
        #expect(try await store.history().count == 2)
    }
}
