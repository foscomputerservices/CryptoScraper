// HyperliquidErrors.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import Foundation

// What Hyperliquid's client throws is C30's one ExchangeClientError (the owner's ruling of 2026-10-06). Hyperliquid's
// own wire errors map into its cases here, once:
//
// - HTTP 429 (Retry-After as whole seconds, when sent)       → rateLimited(retryAfter:), in the client's fetch hook
// - HTTP 401 or 403                                           → unauthorized(text: the body)
// - any other HTTP refusal (a coin not listed is 500, "null") → refused(code: the status, text: the body)
// - an "err" status in a 200, naming a wallet that does not exist (the agent's approval is gone) → unauthorized(text:)
// - any other "err" status, and a cancel status "error" in its words → refused(code: nil, text:); an order status
//   "error" is returned as the result .refused(code: "order", text:), not thrown (an immediate-or-cancel order that
//   could not match is .cancelledBeforeAccepted)
// - a transport failure → unreachable; a body or a number that does not decode → malformedResponse (CryptoExchange's reading)
// - a client made without a credential, or with a key that is no secp256k1 secret, or not an agent → unauthorized(text:)
// - what the client was asked that Hyperliquid lacks or does not list → refused(code: nil, text:), Hyperliquid's refusal being the nearest meaning
// - a holding the table lacks or the statement does not declare, and the units check's finding (Hyperliquid stating
//   other size decimals than the declared holding's, AR45) → refused(code: nil, text:), the nearest meaning

extension ExchangeClientError {
    static let noCredential = ExchangeClientError.unauthorized(text: "The client was made without a credential")
    static let notAnAgent = ExchangeClientError.unauthorized(text: "Hyperliquid does not know the key as an agent of any main wallet")
    static let malformedAgentKey = ExchangeClientError.unauthorized(text: "The agent key is not 32 bytes of a valid secp256k1 secret")
    static let wrongAsset = ExchangeClientError.refused(code: nil, text: "A size or a price in an asset other than the market's, or a transfer of an asset other than USDC")
    static let transferNeedsTheMainAccount = ExchangeClientError.refused(code: nil, text: "Hyperliquid moves funds only between the main account and one of its sub-accounts")

    static func malformedAddress(_ address: String) -> ExchangeClientError {
        .refused(code: nil, text: "An address that is not 20 bytes of hex: \(address)")
    }

    static func unknownAccount(_ account: String) -> ExchangeClientError {
        .refused(code: nil, text: "An account that is neither an address nor a sub-account the main wallet lists: \(account)")
    }

    static func unknownMarket(_ market: HyperliquidMarketName) -> ExchangeClientError {
        .refused(code: nil, text: "Hyperliquid lists no market \(market.text)")
    }

    static func unknownAsset(_ name: String) -> ExchangeClientError {
        .refused(code: nil, text: "Hyperliquid's \(name) is no declared holding")
    }

    /// Hyperliquid's HTTP refusal, its body as it wrote it
    static func rejected(status: Int, text: String) -> ExchangeClientError {
        status == 401 || status == 403 ? .unauthorized(text: text) : .refused(code: String(status), text: text)
    }

    /// Hyperliquid's own error body, decoded by the fetch, as the shared cases; nil for every other error
    static func hyperliquid(_ error: any Error) -> ExchangeClientError? {
        switch error {
        case let api as HyperliquidAPIError:
            // The agent's approval is gone, or never was: Hyperliquid says no such wallet exists
            api.text.hasPrefix("User or API Wallet") && api.text.hasSuffix("does not exist.")
                ? .unauthorized(text: api.text)
                : .refused(code: nil, text: api.text)
        case let statement as AssetRegistryError:
            .refused(code: nil, text: String(describing: statement))
        default:
            nil
        }
    }
}
