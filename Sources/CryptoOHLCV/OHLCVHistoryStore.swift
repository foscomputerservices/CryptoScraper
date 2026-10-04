// OHLCVHistoryStore.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// Where ``OHLCVHistoryRetrieval`` keeps a history: one market's closed bars at one interval, in order, with the
/// gaps the feed left between them
///
/// The retrieval reads the last bar kept, to resume after it, and appends what it fetched. A store keeps what it is
/// handed, in the order handed, and never fills, judges or reorders. This library ships ``OHLCVHistoryFileStore``;
/// a system conforms its own store, over its database, beside it.
///
/// ```swift
/// let store = OHLCVHistoryFileStore<BinanceMarketName>(directory: folder)
/// let retrieval = OHLCVHistoryRetrieval(client: BinanceOHLCVClient(), store: store)
/// try await retrieval.retrieve(market: market, interval: day, from: start, through: end)
/// let kept = try await store.history(market: market, interval: day)
/// ```
public protocol OHLCVHistoryStore: Sendable {
    associatedtype MarketName: Hashable & Sendable

    /// The last bar kept for the market at the interval, or `nil` when none is kept
    func lastBar(market: MarketName, interval: BarInterval) async throws -> OHLCVClientBar?

    /// Keeps `bars`, which open after the last bar kept, in order, and the `gaps` found up to the last of them
    func append(_ bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap], market: MarketName, interval: BarInterval) async throws

    /// Everything kept for the market at the interval, in the order kept
    func history(market: MarketName, interval: BarInterval) async throws -> OHLCVHistory
}

/// One market's kept history at one interval: its bars in order and the gaps between them
///
/// ```swift
/// let kept = try await store.history(market: market, interval: day)
/// kept.bars.count                        // the closed bars the feed gave
/// kept.gaps.map(\.missingBarCount)       // what it did not give, where it did not give it
/// ```
public struct OHLCVHistory: Codable, Hashable, Sendable, Stubbable {
    public let bars: [OHLCVClientBar]
    public let gaps: [OHLCVHistoryGap]

    public init(bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap]) {
        self.bars = bars
        self.gaps = gaps
    }
}

/// A place where the feed's answer skipped bars: two kept bars further apart than one interval
///
/// A gap is a fact of the feed, kept beside the bars and never filled. Whether a gap matters, and for how long, is
/// the caller's to judge.
///
/// ```swift
/// for gap in kept.gaps {
///     print(gap.lastBarOpenTime, gap.nextBarOpenTime, gap.missingBarCount)
/// }
/// ```
public struct OHLCVHistoryGap: Codable, Hashable, Sendable, Stubbable {
    /// The open time of the last bar before the gap
    public let lastBarOpenTime: Date
    /// The open time of the first bar after the gap
    public let nextBarOpenTime: Date
    /// The whole intervals between the two bars' open times less one: the bars the feed did not give
    ///
    /// Zero when the next bar opened off the interval's step, less than one interval past the expected open.
    public let missingBarCount: Int

    public init(lastBarOpenTime: Date, nextBarOpenTime: Date, missingBarCount: Int) {
        self.lastBarOpenTime = lastBarOpenTime
        self.nextBarOpenTime = nextBarOpenTime
        self.missingBarCount = missingBarCount
    }
}
