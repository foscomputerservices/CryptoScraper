// FearGreedClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// The public contract of a Fear and Greed publisher: the index it published, one value a day
///
/// A publisher states, for each day, a value from 0 (extreme fear) to 100 (extreme greed) and its own word for it.
/// A day the publisher is still updating is never handed up.
///
/// ```swift
/// let all = try await client.fearGreedHistory()            // every final day, oldest first
/// let recent = try await client.fearGreed(lastDays: 30)     // the final days among the last thirty
/// ```
public protocol FearGreedClient: Sendable {
    /// Every day the publisher has published and will not update again, oldest first
    func fearGreedHistory() async throws -> [FearGreedDay]

    /// The final days among the publisher's latest `count`, oldest first
    func fearGreed(lastDays count: Int) async throws -> [FearGreedDay]
}

/// One day of a Fear and Greed index as its publisher stated it
///
/// ```swift
/// let day = days.last!
/// day.value             // 24
/// day.classification    // "Extreme Fear", the publisher's word, verbatim
/// ```
///
/// Encodes with its synthesized shape, the one serialization ``FearGreedHistoryFileStore`` writes.
public struct FearGreedDay: Codable, Hashable, Sendable, Stubbable {
    /// The instant the publisher stamped the value with, UTC
    public let timestamp: Date
    /// The index, 0 to 100, decoded exactly from the publisher's text
    public let value: Int
    /// The publisher's own word for the value, verbatim and in its own case
    public let classification: String

    public init(timestamp: Date, value: Int, classification: String) {
        self.timestamp = timestamp
        self.value = value
        self.classification = classification
    }
}

// The owner's nested two-stub form (C7): `stub()` delegates to `stub(…)`, whose every parameter defaults to the
// reserved fake: 42 days after 1970-01-01 UTC, the value 42, the word "Stub 42".
extension FearGreedDay {
    public static func stub() -> Self { .stub(value: 42) }

    /// Day 42 after the epoch, the value 42, the word "Stub 42"
    ///
    /// ```swift
    /// let fear = FearGreedDay.stub(value: 8, classification: "Extreme Fear")
    /// ```
    public static func stub(
        timestamp: Date = Date(timeIntervalSince1970: 42 * 86_400),
        value: Int = 42,
        classification: String = "Stub 42"
    ) -> Self {
        .init(timestamp: timestamp, value: value, classification: classification)
    }
}
