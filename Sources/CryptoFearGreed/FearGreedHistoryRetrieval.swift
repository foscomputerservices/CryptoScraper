// FearGreedHistoryRetrieval.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// Grows a kept Fear and Greed history to the publisher's last final day
///
/// With nothing kept it asks for the whole history; after that, for the whole days from the last day kept to the clock
/// plus one, and keeps only those after the last day kept, each after the one before it. A hole the publisher left is kept as a hole, never filled.
///
/// ```swift
/// let kept = try await FearGreedHistoryRetrieval(client: client, store: store).retrieve()   // the days this call kept
/// ```
public struct FearGreedHistoryRetrieval<Client: FearGreedClient, Store: FearGreedHistoryStore>: Sendable {
    private let client: Client
    private let store: Store
    private let now: @Sendable () -> Date

    public init(client: Client, store: Store, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.store = store
        self.now = now
    }

    /// The days this call kept
    @discardableResult
    public func retrieve() async throws -> [FearGreedDay] {
        let last = try await store.lastDay()
        let fetched: [FearGreedDay]
        if let last {
            // READING: the days since the last day kept are the whole days from it to the clock, and one more for the
            // day the clock is in, so the publisher's latest rows reach back to the last day kept itself.
            let since = Int(now().timeIntervalSince(last.timestamp) / Self.secondsPerDay)
            fetched = try await client.fearGreed(lastDays: max(since, 0) + 1)
        } else {
            fetched = try await client.fearGreedHistory()
        }

        // Only days after the last day kept, each after the one before it: never a day kept twice.
        var fresh: [FearGreedDay] = []
        var previous = last?.timestamp
        for day in fetched {
            if let previous, day.timestamp <= previous { continue }
            fresh.append(day)
            previous = day.timestamp
        }

        guard !fresh.isEmpty else { return [] }
        try await store.append(fresh)
        return fresh
    }

    // A UTC day's length: the publisher publishes one value every 24 hours.
    private static var secondsPerDay: TimeInterval { 86_400 }
}
