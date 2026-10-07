// ExchangeWireErrors.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
// The errors each exchange states on its public wire, shared, like the market names, by the exchange's OHLCV client
// here and its exchange client in its plug-in library: Kraken's and Coinbase's error bodies, and each exchange's
// "slow down" as a typed limit the OHLCV retrieval waits out (OHLCVClientLimitError).

/// Kraken's own error list, as it sends it beside an empty or missing result: `{"error":["EQuery:Unknown asset pair"]}`
///
/// Decoded by FOSFoundation's fetch as its `errorType`; a body whose list is empty is not an error and does not
/// decode as one.
///
/// ```swift
/// catch let error as KrakenAPIError where error.messages.contains("EOrder:Insufficient funds") { … }
/// ```
public struct KrakenAPIError: Error, Decodable, Hashable, Sendable {
    /// Kraken's messages as it wrote them, each `<severity><category>:<message>`
    public let messages: [String]

    public init(messages: [String]) {
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey {
        case messages = "error"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messages = try container.decode([String].self, forKey: .messages)
        guard !messages.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .messages, in: container, debugDescription: "An empty error list is not an error")
        }
        self.messages = messages
    }

    // Kraken's three ways of saying the caller asked too often.
    package var isLimit: Bool {
        messages.contains { $0.hasPrefix("EAPI:Rate limit exceeded") || $0.hasPrefix("EGeneral:Too many requests") || $0.hasPrefix("EOrder:Rate limit exceeded") }
    }
}

/// Coinbase's own error body: `{"error":"NOT_FOUND","error_details":"…","message":"Product NOPE-USD not supported"}`
///
/// ```swift
/// catch let error as CoinbaseAPIError where error.code == "NOT_FOUND" { … }
/// ```
public struct CoinbaseAPIError: Error, Decodable, Hashable, Sendable {
    /// Coinbase's error code as it wrote it: "NOT_FOUND", "INVALID_ARGUMENT", "unknown"
    public let code: String
    /// Coinbase's message as it wrote it
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case code = "error"
        case message
    }
}

/// Hyperliquid asked the caller to slow down: HTTP 429
public struct HyperliquidLimitError: OHLCVClientLimitError, Hashable {
    /// How long Hyperliquid asked the caller to wait, or `nil` when it did not say
    public let retryAfter: Duration?

    public init(retryAfter: Duration?) {
        self.retryAfter = retryAfter
    }
}

/// Kraken asked the caller to slow down: HTTP 429, or "EAPI:Rate limit exceeded", "EGeneral:Too many requests" or
/// "EOrder:Rate limit exceeded" in its error list
public struct KrakenLimitError: OHLCVClientLimitError, Hashable {
    /// How long Kraken asked the caller to wait, or `nil` when it did not say (Kraken's error list never does)
    public let retryAfter: Duration?
    /// Kraken's own error list, when it sent one
    public let apiError: KrakenAPIError?

    public init(retryAfter: Duration?, apiError: KrakenAPIError?) {
        self.retryAfter = retryAfter
        self.apiError = apiError
    }
}

/// Coinbase asked the caller to slow down: HTTP 429
public struct CoinbaseLimitError: OHLCVClientLimitError, Hashable {
    /// How long Coinbase asked the caller to wait, or `nil` when it did not say
    public let retryAfter: Duration?
    /// Coinbase's own body, when it sent one
    public let apiError: CoinbaseAPIError?

    public init(retryAfter: Duration?, apiError: CoinbaseAPIError?) {
        self.retryAfter = retryAfter
        self.apiError = apiError
    }
}

// The hooks' shared reads of a response (AR69): every exchange here sends Retry-After as whole seconds when it sends it.
package enum WireResponse {
    package static func retryAfter(_ response: HTTPURLResponse) -> Duration? {
        response.value(forHTTPHeaderField: "Retry-After")
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map { Duration.seconds($0) }
    }

    // A body decoded as `T` when it is one, else nil: the hook asks "is this the exchange's error shape?", and a body
    // that is not is no error of the hook's.
    package static func decoded<T: Decodable>(_ body: Data?, as _: T.Type) -> T? {
        guard let body else { return nil }
        do {
            return try body.fromJSON()
        } catch {
            return nil // not this shape: the fetch reads the response as it otherwise would
        }
    }
}
