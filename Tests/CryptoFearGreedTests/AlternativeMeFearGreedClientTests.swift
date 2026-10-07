// AlternativeMeFearGreedClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoFearGreed
import FOSFoundation
import Foundation
import Testing

// § 1 of the sentiment source design for Alternative.me's client, against the recorded responses: the whole history
// oldest first from 2018-02-01, the day still being updated dropped, the last days, and malformed text as its typed
// error with the text.

@Suite("Alternative.me Fear and Greed client")
struct AlternativeMeFearGreedClientTests {
    // MARK: The whole history

    @Test func theWholeHistoryDecodesOldestFirstFromTheFirstDay() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let days = try await client(session).fearGreedHistory()

        // 3,167 rows recorded, the newest the day still being updated: 3,166 final days.
        #expect(Recorded.rows(Recorded.whole).count == 3167)
        #expect(days.count == 3166)
        #expect(days.first == FearGreedDay(timestamp: Recorded.firstDay, value: 30, classification: "Fear"))
        #expect(days.last == FearGreedDay(timestamp: Recorded.lastFinalDay, value: 73, classification: "Greed"))
        #expect(zip(days, days.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
    }

    @Test func everyDayIsTheRecordedRowExactly() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let days = try await client(session).fearGreedHistory()
        let rows = Recorded.rows(Recorded.whole).filter { $0["time_until_update"] == nil }.reversed()

        #expect(days.count == rows.count)
        for (day, row) in zip(days, rows) {
            #expect(String(Int(day.timestamp.timeIntervalSince1970)) == row["timestamp"] as? String)
            #expect(String(day.value) == row["value"] as? String)
            #expect(day.classification == row["value_classification"] as? String)
        }
    }

    @Test func theRequestAsksTheWholeHistoryAsJSON() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        _ = try await client(session).fearGreedHistory()
        let request = try #require(session.requests.first)

        #expect(session.requests.count == 1)
        #expect(request.url!.host == "api.alternative.me")
        #expect(request.url!.absoluteString.hasPrefix("https://api.alternative.me/fng/?"))
        #expect(request.query("limit") == "0")
        #expect(request.query("format") == "json")
    }

    @Test func theDayStillBeingUpdatedIsDropped() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let days = try await client(session).fearGreedHistory()

        #expect(Recorded.rows(Recorded.whole).first?["time_until_update"] != nil)
        #expect(!days.contains { $0.timestamp == Recorded.inProgressDay })
    }

    @Test func thePublishersHolesAreKeptAsHoles() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let stamps = Set(try await client(session).fearGreedHistory().map(\.timestamp))

        // 2018-04-14, 15 and 16, and 2024-10-26: the publisher published nothing for them.
        for missing in [day(17635), day(17636), day(17637), day(20022)] {
            #expect(!stamps.contains(missing))
        }
        #expect(stamps.contains(day(17634)) && stamps.contains(day(17638)))
        #expect(stamps.contains(day(20021)) && stamps.contains(day(20023)))
    }

    @Test func theWordsAreThePublishersVerbatim() async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let days = try await client(session).fearGreedHistory()

        #expect(Set(days.map(\.classification)) == ["Extreme Fear", "Fear", "Neutral", "Greed", "Extreme Greed"])
        #expect(days.map(\.value).min() == 5)
        #expect(days.map(\.value).max() == 95)
    }

    // MARK: The last days

    @Test func theLastThirtyHandUpTheFinalDaysAmongThem() async throws {
        let session = ReplaySession { _ in .ok(Recorded.lastThirty) }
        let days = try await client(session).fearGreed(lastDays: 30)

        #expect(Recorded.rows(Recorded.lastThirty).count == 30)
        #expect(days.count == 29)
        #expect(days.first?.timestamp == Recorded.lastThirtyFirstDay)
        #expect(days.last == FearGreedDay(timestamp: Recorded.lastFinalDay, value: 73, classification: "Greed"))
        #expect(zip(days, days.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
        #expect(session.requests.first?.query("limit") == "30")
        #expect(session.requests.first?.query("format") == "json")
    }

    @Test func theLastThirtyAreTheWholeHistorysLastDays() async throws {
        let whole = try await client(ReplaySession(route: alternativeMeRoute)).fearGreedHistory()
        let recent = try await client(ReplaySession { _ in .ok(Recorded.lastThirty) }).fearGreed(lastDays: 30)

        #expect(Array(whole.suffix(recent.count)) == recent)
    }

    @Test(arguments: [0, -1])
    func aCountBelowOneAsksNothing(count: Int) async throws {
        let session = ReplaySession(route: alternativeMeRoute)
        let days = try await client(session).fearGreed(lastDays: count)

        #expect(days.isEmpty)
        #expect(session.requests.isEmpty)
    }

    // MARK: Malformed text, at the wire

    @Test(arguments: ["abc", "", "4.5", "101", "-1", " 5", "+5", "1e1", "٥"])
    func aValueThatIsNotAWholeNumberFromZeroToAHundredIsMalformed(text: String) async throws {
        let body = row(value: text, timestamp: "1517443200")
        let session = ReplaySession { _ in .ok(body) }
        await #expect(throws: AlternativeMeFearGreedError.malformedValue(text)) {
            try await client(session).fearGreedHistory()
        }
    }

    @Test(arguments: ["abc", "", "1517443200.5", "1e9", "-1517443200", " 1517443200", "+1517443200"])
    func aTimestampThatIsNotWholeUnixSecondsIsMalformed(text: String) async throws {
        let body = row(value: "30", timestamp: text)
        let session = ReplaySession { _ in .ok(body) }
        await #expect(throws: AlternativeMeFearGreedError.malformedTimestamp(text)) {
            try await client(session).fearGreed(lastDays: 1)
        }
    }

    @Test(arguments: ["0", "100", "007"])
    func aValueAtTheScalesEdgesIsRead(text: String) async throws {
        let body = row(value: text, timestamp: "1517443200")
        let session = ReplaySession { _ in .ok(body) }
        let days = try await client(session).fearGreedHistory()
        #expect(days.map(\.value) == [Int(text)!])
    }

    @Test func aFailedResponseIsTheFetchsError() async throws {
        let session = ReplaySession { _ in Reply(status: 500, body: Data("{}".utf8)) }
        await #expect(throws: DataFetchError.self) {
            try await client(session).fearGreedHistory()
        }
    }

    // One final row in the recorded envelope.
    private func row(value: String, timestamp: String) -> Data {
        Recorded.response(Recorded.whole, rows: [
            ["value": value, "value_classification": "Fear", "timestamp": timestamp]
        ])
    }
}
