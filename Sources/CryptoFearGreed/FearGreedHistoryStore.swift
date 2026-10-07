// FearGreedHistoryStore.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// Where a Fear and Greed history is kept: one publisher's final days, in order
///
/// The retrieval reads the last day kept, to resume after it, and appends what it fetched. A store keeps what it is
/// handed, in the order handed, and never fills, judges or reorders. This library ships ``FearGreedHistoryFileStore``;
/// a system conforms its own store, over its database, beside it.
///
/// ```swift
/// let store = FearGreedHistoryFileStore(file: folder.appending(path: "alternative-me.jsonl"))
/// try await FearGreedHistoryRetrieval(client: AlternativeMeFearGreedClient(), store: store).retrieve()
/// let kept = try await store.history()
/// ```
public protocol FearGreedHistoryStore: Sendable {
    /// The last day kept, or `nil` when none is kept
    func lastDay() async throws -> FearGreedDay?

    /// Keeps `days`, which follow the last day kept, in order
    func append(_ days: [FearGreedDay]) async throws

    /// Everything kept, in the order kept
    func history() async throws -> [FearGreedDay]
}
