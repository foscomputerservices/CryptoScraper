// OHLCVClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// The public contract of one feed's OHLCV client: closed bars for a market over an absolute UTC range
///
/// The client takes an interval as a count and a unit and an absolute range it does not round. Bar alignment is
/// the consumer's; this client has no calendar.
///
/// ```swift
/// let market = try BinanceMarketName(validating: "BTCUSDT")
/// let bars = try await client.ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute), from: start, through: end)
/// let open = try await client.openOHLCV(market: market, interval: BarInterval(count: 1, unit: .day))
/// ```
///
/// One call is one request to the feed, so it hands up at most the feed's page of bars: the earliest closed bars
/// whose open time falls in the range, in order. A history longer than a page is the work of
/// ``OHLCVHistoryRetrieval``, which pages by the last bar it kept.
public protocol OHLCVClient: Sendable {
    associatedtype MarketName: Hashable & Sendable
    func ohlcv(market: MarketName, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar]
    /// The still-open bar: its open time and its open price so far; never a closed bar's stand-in, so `nil` when the
    /// feed's newest bar has closed or the feed answers none
    func openOHLCV(market: MarketName, interval: BarInterval) async throws -> OHLCVClientBar?
}

/// A bar as the feed gave it, every number parsed exactly from the feed's text
///
/// ```swift
/// let bar = bars.last!
/// try bar.close.cost(of: bar.volume)      // the bar's volume at its close, in the quote asset, exact
/// bar.isClosed                            // true for every bar `ohlcv` hands up
/// ```
///
/// Encodes with its synthesized shape, the one serialization ``OHLCVHistoryFileStore`` writes.
public struct OHLCVClientBar: Codable, Hashable, Sendable, Stubbable {
    /// The instant the bar opened, UTC
    public let openTime: Date
    /// The instant the feed says the bar closes, UTC, as the feed states it (Binance: the bar's last millisecond)
    public let closeTime: Date
    public let open: Price
    public let high: Price
    public let low: Price
    public let close: Price
    /// The base asset traded during the bar
    public let volume: Amount
    /// The count of trades, where the feed gives one
    public let trades: Int?
    /// `false` only for the still-open bar ``OHLCVClient/openOHLCV(market:interval:)`` hands up
    public let isClosed: Bool

    public init(openTime: Date, closeTime: Date, open: Price, high: Price, low: Price, close: Price,
                volume: Amount, trades: Int?, isClosed: Bool) {
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.trades = trades
        self.isClosed = isClosed
    }
}

// The owner's nested two-stub form (C7): `stub()` delegates to `stub(…)`, whose every parameter defaults to its own
// type's stub, or to the reserved fake where the type is a plain number, text or date. The fake times: 42 days after
// 1970-01-01 UTC, the bar of that day, closing at its last millisecond.
extension OHLCVClientBar {
    public static func stub() -> Self { .stub(isClosed: true) }

    /// A bar with any piece overridden, every other piece its own type's stub
    ///
    /// ```swift
    /// let open = OHLCVClientBar.stub(isClosed: false)
    /// ```
    public static func stub(
        openTime: Date = Date(timeIntervalSince1970: 42 * 86_400),
        closeTime: Date = Date(timeIntervalSince1970: 43 * 86_400 - 0.001),
        open: Price = .stub(),
        high: Price = .stub(),
        low: Price = .stub(),
        close: Price = .stub(),
        volume: Amount = .stub(of: Price.stub().base),
        trades: Int? = 42,
        isClosed: Bool = true
    ) -> Self {
        .init(
            openTime: openTime,
            closeTime: closeTime,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            trades: trades,
            isClosed: isClosed
        )
    }
}

/// An error a client throws when the feed asked it to slow down, which ``OHLCVHistoryRetrieval`` waits out
///
/// ```swift
/// catch let limit as any OHLCVClientLimitError {
///     try await Task.sleep(for: limit.retryAfter ?? .seconds(1))
/// }
/// ```
public protocol OHLCVClientLimitError: Error, Sendable {
    /// How long the feed asked the caller to wait, or `nil` when it did not say
    var retryAfter: Duration? { get }
}
