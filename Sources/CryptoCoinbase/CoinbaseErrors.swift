// CoinbaseErrors.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import Foundation

// What Coinbase's client throws is C30's one ExchangeClientError (the owner's ruling of 2026-10-06). Coinbase's own
// wire errors map into its cases here, once:
//
// - HTTP 429 (Retry-After as whole seconds, when sent) → rateLimited(retryAfter:)
// - an error body whose code is "unauthorized" or "unauthenticated" → unauthorized(text: the message)
// - any other error body `{"error", "message"}` → refused(code: Coinbase's error, text: its message)
// - a create or cancel answered `success: false` → refused(code: the failure reason, text: its message), as a result or thrown
// - a transport failure → unreachable; a body or a number that does not decode → malformedResponse (CryptoExchange's reading)
// - the member Coinbase lacks (leverage) → notOffered(member:)
// - a client made without a credential, or with a malformed one → unauthorized(text:)
// - a size or a price in an asset other than the product's → refused(code: nil, text:), the nearest meaning
// - an account state asked of a portfolio other than the key's own → refused(code: nil, text:) naming both
// - a currency the table lacks or the statement does not declare, and the units check's finding (an increment finer
//   than the declared holding's decimals, AR45) → refused(code: nil, text:), the nearest meaning

extension ExchangeClientError {
    static let noCredential = ExchangeClientError.unauthorized(text: "The client was made without a credential")
    static let malformedCredential = ExchangeClientError.unauthorized(text: "A Coinbase key name and its P-256 private key in PEM are both needed")
    static let wrongAsset = ExchangeClientError.refused(code: nil, text: "A size or a price in an asset other than the product's, or a transfer of an asset that is not one")
    /// Coinbase Advanced Trade sets no leverage on a market or an account
    static let leverageNotSettable = ExchangeClientError.notOffered(member: "setLeverage")

    static func unknownAsset(_ name: String) -> ExchangeClientError {
        .refused(code: nil, text: "Coinbase's \(name) is no declared holding")
    }

    static func notTheKeysPortfolio(_ account: String, keys portfolio: String) -> ExchangeClientError {
        .refused(code: nil, text: "Coinbase reads only the key's own portfolio, \(portfolio), not \(account)")
    }

    static func malformedOrderId(_ candidate: String) -> ExchangeClientError {
        .malformedResponse(text: "An order id that is not one Coinbase could write: \(candidate)")
    }

    static func malformedTradeId(_ candidate: String) -> ExchangeClientError {
        .malformedResponse(text: "A trade id that is not one Coinbase could write: \(candidate)")
    }

    static func malformedCursor(_ candidate: String) -> ExchangeClientError {
        .malformedResponse(text: "A cursor that is not an RFC 3339 time: \(candidate)")
    }

    /// Coinbase's own errors, typed by its fetch hook or decoded by the fetch, as the shared cases; nil for every other error
    static func coinbase(_ error: any Error) -> ExchangeClientError? {
        switch error {
        case let limit as CoinbaseLimitError:
            .rateLimited(retryAfter: limit.retryAfter)
        case let api as CoinbaseAPIError:
            ["unauthorized", "unauthenticated"].contains(api.code.lowercased())
                ? .unauthorized(text: api.message)
                : .refused(code: api.code, text: api.message)
        case let statement as AssetRegistryError:
            .refused(code: nil, text: String(describing: statement))
        default:
            nil
        }
    }
}
