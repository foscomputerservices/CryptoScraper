// OHLCVHistoryRetrieval.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// The OHLCV retrieval: fetches a market's history over an ``OHLCVClient`` and keeps it in an ``OHLCVHistoryStore``
///
/// A range longer than one page is fetched page by page, each page asked from just after the last bar kept, so the
/// bars are kept in order with nothing dropped or doubled. A page is put in open-time order before it is kept, so a
/// feed that answers out of order loses nothing, and a bar it answers twice is kept once. Each page is kept as it
/// arrives, so a retrieval that stops part way resumes, on its next call, from the last bar kept. Two kept bars whose
/// open times are not exactly one interval apart are kept as an ``OHLCVHistoryGap``; the gap is never filled and
/// never judged. A limit response is waited out, for the feed's `Retry-After` or else a doubling wait, and the same
/// page asked again.
///
/// ```swift
/// let retrieval = OHLCVHistoryRetrieval(client: BinanceOHLCVClient(), store: OHLCVHistoryFileStore(directory: folder))
/// let first = try await retrieval.retrieve(market: market, interval: day, from: listing, through: yesterday)
/// let later = try await retrieval.retrieve(market: market, interval: day, from: listing, through: today)  // only the new bars
/// ```
///
/// The range is absolute UTC and is not rounded: bar alignment is the caller's. A retrieval only extends a kept
/// history forward; it never fetches before the last bar kept.
public struct OHLCVHistoryRetrieval<Client: OHLCVClient, Store: OHLCVHistoryStore>: Sendable
    where Store.MarketName == Client.MarketName {
    private let client: Client
    private let store: Store
    private let backoff: OHLCVHistoryBackoff
    private let sleep: @Sendable (Duration) async throws -> Void

    /// - Parameters:
    ///   - client: The feed
    ///   - store: Where the history is kept
    ///   - backoff: How limit responses are waited out
    ///   - sleep: How a wait is taken; a test passes a clock that only records
    public init(
        client: Client,
        store: Store,
        backoff: OHLCVHistoryBackoff = .init(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.client = client
        self.store = store
        self.backoff = backoff
        self.sleep = sleep
    }

    /// Fetches the market's closed bars opening from `from` through `through`, after the last bar kept, and keeps
    /// them with the gaps found
    ///
    /// - Returns: What this call kept: the bars and the gaps, and the requests it made
    /// - Throws: The client's error; the limit error of the ``OHLCVHistoryBackoff/attempts``-th limit response in a
    ///   row on one page, the ones before it waited out; the store's error. Every page kept before the error stays
    ///   kept.
    /// - Precondition: `interval` has a length; an interval of no length traps
    @discardableResult
    public func retrieve(market: Client.MarketName, interval: BarInterval, from: Date, through: Date) async throws -> OHLCVHistoryRetrievalResult {
        let step = interval.milliseconds
        precondition(step > 0, "OHLCVHistoryRetrieval with an interval of no length")

        var last = try await store.lastBar(market: market, interval: interval)
        var cursor = from.milliseconds
        if let last {
            cursor = max(cursor, last.openTime.milliseconds + 1)
        }
        let end = through.milliseconds

        var keptBars: [OHLCVClientBar] = []
        var keptGaps: [OHLCVHistoryGap] = []
        var requests = 0

        while cursor <= end {
            let (page, asked) = try await page(market: market, interval: interval, from: cursor, through: end)
            requests += asked

            // The page in open-time order, whatever order the feed answered it in; then only closed bars, opening
            // inside the range and after the last bar kept: never one kept twice.
            var fresh: [OHLCVClientBar] = []
            var gaps: [OHLCVHistoryGap] = []
            var previous = last
            for bar in page.sorted(by: { $0.openTime < $1.openTime }) where bar.isClosed {
                let open = bar.openTime.milliseconds
                guard open >= cursor, open <= end else { continue }
                if let previous {
                    let before = previous.openTime.milliseconds
                    guard open > before else { continue }
                    if open - before != step {
                        gaps.append(OHLCVHistoryGap(
                            lastBarOpenTime: previous.openTime,
                            nextBarOpenTime: bar.openTime,
                            missingBarCount: Int((open - before) / step - 1)
                        ))
                    }
                }
                fresh.append(bar)
                previous = bar
            }

            // An empty page, or one with nothing new, is the end of what the feed has in the range.
            guard let newest = fresh.last else { break }

            try await store.append(fresh, gaps: gaps, market: market, interval: interval)
            keptBars += fresh
            keptGaps += gaps
            last = newest
            cursor = newest.openTime.milliseconds + 1
        }

        return OHLCVHistoryRetrievalResult(bars: keptBars, gaps: keptGaps, requestCount: requests)
    }

    // One page, waiting out limit responses. Returns the page and the requests it took.
    private func page(market: Client.MarketName, interval: BarInterval, from: Int64, through: Int64) async throws -> ([OHLCVClientBar], Int) {
        var limits = 0
        while true {
            do {
                let bars = try await client.ohlcv(
                    market: market,
                    interval: interval,
                    from: Date(milliseconds: from),
                    through: Date(milliseconds: through)
                )
                return (bars, limits + 1)
            } catch let limit as any OHLCVClientLimitError {
                limits += 1
                guard limits < backoff.attempts else { throw limit }
                try await sleep(backoff.wait(afterLimit: limits, retryAfter: limit.retryAfter))
            }
        }
    }
}

/// How ``OHLCVHistoryRetrieval`` waits out a limit response
///
/// The wait is the feed's `Retry-After` when it sent one, taken as sent and never capped, else `firstWait` doubled
/// for each limit in a row after the first, never longer than `longestWait`. The `attempts`-th limit response in a
/// row on one page is thrown, not waited out.
///
/// ```swift
/// let patient = OHLCVHistoryBackoff(attempts: 10, firstWait: .seconds(2), longestWait: .seconds(300))
/// ```
public struct OHLCVHistoryBackoff: Hashable, Sendable, Stubbable {
    /// The limit responses in a row on one page after which the retrieval gives up
    public let attempts: Int
    /// The wait after the first limit response with no `Retry-After`
    public let firstWait: Duration
    /// The longest wait the doubling reaches
    public let longestWait: Duration

    public init(attempts: Int = 6, firstWait: Duration = .seconds(1), longestWait: Duration = .seconds(120)) {
        self.attempts = attempts
        self.firstWait = firstWait
        self.longestWait = longestWait
    }

    /// The wait after the `count`-th limit response in a row, 1 for the first
    public func wait(afterLimit count: Int, retryAfter: Duration?) -> Duration {
        if let retryAfter {
            return retryAfter
        }
        var wait = firstWait
        for _ in 1..<max(count, 1) where wait < longestWait {
            wait *= 2
        }
        return min(wait, longestWait)
    }
}

extension OHLCVHistoryBackoff {
    public static func stub() -> Self { .stub(attempts: 42) }

    public static func stub(attempts: Int = 42, firstWait: Duration = .seconds(42), longestWait: Duration = .seconds(42 * 42)) -> Self {
        .init(attempts: attempts, firstWait: firstWait, longestWait: longestWait)
    }
}

/// What one call of ``OHLCVHistoryRetrieval/retrieve(market:interval:from:through:)`` kept
///
/// ```swift
/// let result = try await retrieval.retrieve(market: market, interval: day, from: start, through: end)
/// result.bars.count       // the bars kept by this call
/// result.gaps             // the gaps found by this call
/// ```
public struct OHLCVHistoryRetrievalResult: Hashable, Sendable, Stubbable {
    /// The bars this call kept, in order
    public let bars: [OHLCVClientBar]
    /// The gaps this call found, in order
    public let gaps: [OHLCVHistoryGap]
    /// The requests this call made of the client, limit responses included
    public let requestCount: Int

    public init(bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap], requestCount: Int) {
        self.bars = bars
        self.gaps = gaps
        self.requestCount = requestCount
    }
}

extension OHLCVHistoryRetrievalResult {
    public static func stub() -> Self { .stub(requestCount: 42) }

    public static func stub(bars: [OHLCVClientBar] = [.stub()], gaps: [OHLCVHistoryGap] = [], requestCount: Int = 42) -> Self {
        .init(bars: bars, gaps: gaps, requestCount: requestCount)
    }
}
