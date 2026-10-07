// BinanceOHLCVError.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// The error Binance states in its own body: `{"code":-1121,"msg":"Invalid symbol."}`
///
/// Decoded by FOSFoundation's fetch as its `errorType` whenever a response is not the value asked for.
///
/// ```swift
/// do { _ = try await client.ohlcv(market: market, interval: day, from: start, through: end) }
/// catch let error as BinanceAPIError where error.code == -1121 { … }     // Binance does not list the market
/// ```
public struct BinanceAPIError: Error, Decodable, Hashable, Sendable {
    /// Binance's error code, negative: -1121 an invalid symbol, -1003 too much request weight
    public let code: Int
    /// Binance's message, as it wrote it
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case message = "msg"
    }
}

/// Binance asked the caller to slow down: HTTP 429, or 418 once the caller kept asking after a 429
///
/// ```swift
/// catch let limit as BinanceLimitError {
///     limit.status          // 429 or 418
///     limit.retryAfter      // Binance's Retry-After, when it sent one
/// }
/// ```
public struct BinanceLimitError: OHLCVClientLimitError, Hashable {
    /// The HTTP status: 429, or 418 for an address Binance has banned for a while
    public let status: Int
    /// How long Binance asked the caller to wait, from its `Retry-After` header, or `nil` when it sent none
    public let retryAfter: Duration?
    /// Binance's own body for the limit, when it sent one
    public let apiError: BinanceAPIError?

    public init(status: Int, retryAfter: Duration?, apiError: BinanceAPIError?) {
        self.status = status
        self.retryAfter = retryAfter
        self.apiError = apiError
    }
}

/// Why ``BinanceOHLCVClient`` could not hand up what was asked, where Binance itself said nothing wrong
///
/// ```swift
/// catch BinanceOHLCVError.unsupportedInterval(let interval) { … }
/// ```
public enum BinanceOHLCVError: Error, Hashable, Sendable {
    /// Binance has no kline interval of this length: it lists 1, 3, 5, 15 and 30 minutes; 1, 2, 4, 6, 8 and 12
    /// hours; 1 and 3 days; 1 week
    case unsupportedInterval(BarInterval)
    /// A market's name that is not one to twenty ASCII letters and digits
    case malformedMarketName(String)
    /// `/api/v3/exchangeInfo` did not list the market, or one of its holdings is not declared
    case unknownMarket(BinanceMarketName)
}
