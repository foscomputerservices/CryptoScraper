// AlternativeMeFearGreedClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Alternative.me's Fear and Greed client, on `/fng/`
///
/// Each call is one request through FOSFoundation's fetch, asking `limit` and `format=json`: `limit=0` is the whole
/// history, from 2018-02-01. `fearGreed(lastDays:)` with a count below one makes no request and hands up no day, since
/// `limit=0` would ask the whole history. The day still being updated, the one that carries `time_until_update`, is
/// dropped, its presence read and never its value. The days are handed up oldest first, sorted by timestamp.
///
/// ```swift
/// let client = AlternativeMeFearGreedClient()
/// let all = try await client.fearGreedHistory()
/// all.first?.timestamp         // 2018-02-01 UTC
/// ```
///
/// A `value` or a `timestamp` whose text is not a whole number, read from ASCII digits only, or a `value` above 100,
/// throws ``AlternativeMeFearGreedError``; a failed response is FOSFoundation's fetch error.
public struct AlternativeMeFearGreedClient: FearGreedClient {
    private let baseURL: URL
    private let session: any URLSessionProtocol

    /// - Parameters:
    ///   - baseURL: Alternative.me's REST root
    ///   - session: The session the requests go through; a test passes a recorded one
    public init(
        baseURL: URL = URL(string: "https://api.alternative.me")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration())
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fearGreedHistory() async throws -> [FearGreedDay] {
        try await days(limit: 0)
    }

    // READING: a count below one asks nothing and hands up no day, since `limit=0` would ask the whole history.
    public func fearGreed(lastDays count: Int) async throws -> [FearGreedDay] {
        guard count > 0 else { return [] }
        return try await days(limit: count)
    }

    // One GET of `/fng/` through FOSFoundation's fetch, the one place the request is built; the final days, oldest
    // first. The publisher answers newest first; the days are put in time order by their timestamps.
    private func days(limit: Int) async throws -> [FearGreedDay] {
        var components = URLComponents(url: baseURL.appendingPathComponent("fng/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else {
            throw DataFetchError.badURL("fng/ limit=\(limit)")
        }

        let response: AlternativeMeFearGreedResponse = try await Self.fetch(url, on: session)
        return try response.data
            .filter { !$0.isUpdating }
            .map { try $0.day() }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // The session opened to its concrete type, which DataFetch is generic over.
    private static func fetch<Session: URLSessionProtocol, Value: Decodable & Sendable>(_ url: URL, on session: Session) async throws -> Value {
        try await DataFetch(urlSession: session).fetch(url)
    }
}

// MARK: Response models

// The part of `/fng/`'s answer this client reads: its rows, each as the publisher wrote it, every field text.
//   {"name": "Fear and Greed Index", "data": [{"value": "71", "value_classification": "Greed",
//    "timestamp": "1791331200", "time_until_update": "32604"}, …], "metadata": {"error": null}}
struct AlternativeMeFearGreedResponse: Decodable, Sendable {
    let data: [Row]

    struct Row: Decodable, Sendable {
        let value: String
        let classification: String
        let timestamp: String
        // The row carries `time_until_update`: the day still being updated. Its presence is read, never its value.
        let isUpdating: Bool

        private enum CodingKeys: String, CodingKey {
            case value
            case classification = "value_classification"
            case timestamp
            case timeUntilUpdate = "time_until_update"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.value = try container.decode(String.self, forKey: .value)
            self.classification = try container.decode(String.self, forKey: .classification)
            self.timestamp = try container.decode(String.self, forKey: .timestamp)
            self.isUpdating = container.contains(.timeUntilUpdate)
        }

        // The day, its value a whole number from 0 to 100 and its timestamp whole Unix seconds, each read only from
        // ASCII digits so no sign, space, point or exponent passes.
        func day() throws -> FearGreedDay {
            guard let value = Self.whole(value), value <= 100 else {
                throw AlternativeMeFearGreedError.malformedValue(self.value)
            }
            guard let seconds = Self.whole(timestamp) else {
                throw AlternativeMeFearGreedError.malformedTimestamp(timestamp)
            }
            return FearGreedDay(
                timestamp: Date(timeIntervalSince1970: TimeInterval(seconds)),
                value: value,
                classification: classification
            )
        }

        private static func whole(_ text: String) -> Int? {
            guard !text.isEmpty, text.utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }) else {
                return nil
            }
            return Int(text)
        }
    }
}
