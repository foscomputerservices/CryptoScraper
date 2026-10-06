// ExchangeClientErrorMapping.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The one place a failure of a request becomes C30's `ExchangeClientError` (the owner's ruling of 2026-10-06, "yes, one
// shared error type"). A plug-in gives `mapping` its exchange's own translation first (its error body, its limit);
// whatever that leaves is read here: the fetch's errors, the transport's, a decode's.

extension ExchangeClientError {
    /// The shared error a failure of a request is, or `error` itself when it is a cancellation
    ///
    /// - Parameters:
    ///   - error: What the request threw
    ///   - translating: The exchange's own reading of `error`: its error body, its limit; `nil` leaves it to the shared rules
    package static func mapping(_ error: any Error, translating exchange: (any Error) -> ExchangeClientError? = { _ in nil }) -> any Error {
        if error is ExchangeClientError || error is CancellationError {
            return error
        }
        if let own = exchange(error) {
            return own
        }
        switch error {
        case let fetch as DataFetchError:
            return fetch.asExchangeClientError
        case let transport as URLError:
            return ExchangeClientError.unreachable(text: transport.localizedDescription)
        case is DecodingError, is AmountError, is AssetError, is AssetSymbolError:
            return ExchangeClientError.malformedResponse(text: String(describing: error))
        default:
            // Whatever else a request threw is the transport's (a session's own failure), never the exchange's word
            return ExchangeClientError.unreachable(text: String(describing: error))
        }
    }
}

extension DataFetchError {
    // FOSUtilities 0.20.0's fetch errors read as the shared cases: its `retryAfter` is the exchange's wait
    fileprivate var asExchangeClientError: ExchangeClientError {
        switch self {
        case .retryAfter(let wait):
            .rateLimited(retryAfter: wait)
        case .badStatus(let status) where status == 401 || status == 403:
            .unauthorized(text: "HTTP \(status)")
        case .badStatus(let status):
            .refused(code: String(status), text: "HTTP \(status)")
        case .decoding, .noDataReceived, .badResponseMimeType, .badDateFormat, .utf8DecodingError:
            .malformedResponse(text: debugDescription)
        case .encoding, .badURL, .utf8EncodingError:
            .unreachable(text: debugDescription) // the request could not be made
        }
    }
}
