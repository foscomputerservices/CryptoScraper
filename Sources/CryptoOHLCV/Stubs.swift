// Stubs.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// The owner's nested two-stub form (C7) on every value of this library: `stub()` delegates to `stub(…)`, whose every
// parameter defaults to its own type's stub, or to the reserved fake where the type is a plain number, text or date.
// No statics carry a fake; no default calls the enclosing type's own stub(). Where one value must agree with
// another, the default says so through the nested stub: a bar's volume is `Amount.stub(asset: Price.stub().base)`.
//
// The fake times: 42 days after 1970-01-01 UTC, the bar of that day, closing at its last millisecond.

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
        volume: Amount = .stub(asset: Price.stub().base),
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

extension OHLCVHistoryGap {
    public static func stub() -> Self { .stub(missingBarCount: 42) }

    public static func stub(
        lastBarOpenTime: Date = Date(timeIntervalSince1970: 42 * 86_400),
        nextBarOpenTime: Date = Date(timeIntervalSince1970: (42 + 43) * 86_400),
        missingBarCount: Int = 42
    ) -> Self {
        .init(lastBarOpenTime: lastBarOpenTime, nextBarOpenTime: nextBarOpenTime, missingBarCount: missingBarCount)
    }
}

extension OHLCVHistory {
    public static func stub() -> Self { .stub(gaps: []) }

    public static func stub(bars: [OHLCVClientBar] = [.stub()], gaps: [OHLCVHistoryGap] = []) -> Self {
        .init(bars: bars, gaps: gaps)
    }
}

extension OHLCVHistoryRetrievalResult {
    public static func stub() -> Self { .stub(requestCount: 42) }

    public static func stub(bars: [OHLCVClientBar] = [.stub()], gaps: [OHLCVHistoryGap] = [], requestCount: Int = 42) -> Self {
        .init(bars: bars, gaps: gaps, requestCount: requestCount)
    }
}

extension OHLCVHistoryBackoff {
    public static func stub() -> Self { .stub(attempts: 42) }

    public static func stub(attempts: Int = 42, firstWait: Duration = .seconds(42), longestWait: Duration = .seconds(42 * 42)) -> Self {
        .init(attempts: attempts, firstWait: firstWait, longestWait: longestWait)
    }
}

extension BinanceMarketName {
    public static func stub() -> Self { .stub(text: "FREDBARNEY") }

    public static func stub(text: String = "FREDBARNEY") -> Self {
        do {
            return try BinanceMarketName(validating: text)
        } catch {
            preconditionFailure("BinanceMarketName.stub(text:) with a malformed name: \(error)")
        }
    }
}

extension BinanceMarket {
    public static func stub() -> Self { .stub(name: .stub()) }

    /// FREDBARNEY: the base is Price's stub base, BARNEY, and the quote Price's stub quote, FRED
    public static func stub(
        name: BinanceMarketName = .stub(),
        base: Asset = Price.stub().base,
        quote: Asset = Price.stub().quote
    ) -> Self {
        .init(name: name, base: base, quote: quote)
    }
}
