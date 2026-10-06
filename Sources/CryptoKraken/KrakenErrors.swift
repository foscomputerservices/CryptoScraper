// KrakenErrors.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoOHLCV
import Foundation

// What Kraken's client throws is C30's one ExchangeClientError (the owner's ruling of 2026-10-06). Kraken's own wire
// errors map into its cases here, once:
//
// - HTTP 429, or "EAPI:Rate limit exceeded" / "EGeneral:Too many requests" / "EOrder:Rate limit exceeded" in the
//   error list (the retry hint is Retry-After as whole seconds when sent; the list never gives one) → rateLimited(retryAfter:)
// - HTTP 401 or 403; "EAPI:Invalid key", "EAPI:Invalid signature", "EGeneral:Permission denied" in the list → unauthorized(text:)
// - any other "E…" in the list (`<severity><category>:<message>`) → refused(code: the category, text: the message)
// - a transport failure → unreachable; a body or a number that does not decode → malformedResponse (CryptoExchange's reading)
// - the members Kraken spot lacks → notOffered(member:)
// - a client made without a credential, or with a malformed one → unauthorized(text:)
// - a market, an asset or a size Kraken does not list → refused(code: nil, text:), the nearest meaning

extension ExchangeClientError {
    static let noCredential = ExchangeClientError.unauthorized(text: "The client was made without a credential")
    static let malformedCredential = ExchangeClientError.unauthorized(text: "A Kraken API key and its base64 secret are both needed")
    static let wrongAsset = ExchangeClientError.refused(code: nil, text: "A size or a price in an asset other than the market's")
    /// Kraken spot sets leverage on each order, never on a market or an account
    static let leverageNotSettable = ExchangeClientError.notOffered(member: "setLeverage")
    /// Kraken spot offers no transfer between an account's own wallets through this API
    static let transferNotOffered = ExchangeClientError.notOffered(member: "transfer")
    /// Kraken states no key's permissions or approval through its API
    static let keyFactsNotOffered = ExchangeClientError.notOffered(member: "keyFacts")

    static func malformedOrderId(_ candidate: String) -> ExchangeClientError {
        .malformedResponse(text: "A transaction id that is not one Kraken could write: \(candidate)")
    }

    static func unknownMarket(_ market: KrakenMarketName) -> ExchangeClientError {
        .refused(code: nil, text: "Kraken's AssetPairs lists no market \(market.text)")
    }

    static func unknownAsset(_ key: String) -> ExchangeClientError {
        .refused(code: nil, text: "Kraken's Assets lists no asset \(key)")
    }

    /// Kraken's own errors, typed by its fetch hook or decoded by the fetch, as the shared cases; nil for every other error
    static func kraken(_ error: any Error) -> ExchangeClientError? {
        switch error {
        case let limit as KrakenLimitError:
            .rateLimited(retryAfter: limit.retryAfter)
        case let api as KrakenAPIError:
            api.asExchangeClientError
        default:
            nil
        }
    }
}

extension KrakenAPIError {
    private static let credentialRefusals = ["EAPI:Invalid key", "EAPI:Invalid signature", "EGeneral:Permission denied"]

    fileprivate var asExchangeClientError: ExchangeClientError {
        if isLimit {
            return .rateLimited(retryAfter: nil)
        }
        if messages.contains(where: { message in Self.credentialRefusals.contains { message.hasPrefix($0) } }) {
            return .unauthorized(text: messages.joined(separator: "; "))
        }
        let first = messages.first ?? ""
        guard let colon = first.firstIndex(of: ":") else {
            return .refused(code: nil, text: messages.joined(separator: "; "))
        }
        let words = [String(first[first.index(after: colon)...])] + messages.dropFirst()
        return .refused(code: String(first[..<colon]), text: words.joined(separator: "; "))
    }
}
