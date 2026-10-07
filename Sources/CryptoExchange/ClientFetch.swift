// ClientFetch.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Every request a client in this package makes goes through FOSFoundation's DataFetch with the exchange's error type
// and the client's hook (AR31, AR69): `errorForResponse` sees each response, 2xx included, before DataFetch reads it,
// so a client counts its requests there and turns the exchange's own way of saying "slow down" or "refused" into its
// typed error. A client holds its session as `any URLSessionProtocol`; DataFetch is generic over the session's
// concrete type, so the session is opened here, once, for every client.

package enum ClientFetch {
    /// One request through DataFetch: `method` (GET by default), with the body's exact bytes when `body` is given
    package static func send<Value: Decodable & Sendable, Failure: Decodable & Error>(
        _ url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [(field: String, value: String)] = [],
        session: any URLSessionProtocol,
        errorType: Failure.Type,
        errorForResponse: @escaping @Sendable (HTTPURLResponse, Data?) -> (any Error)?
    ) async throws -> Value {
        try await open(session, url, method, body, headers, errorType, errorForResponse)
    }

    /// One request through DataFetch for a service whose error bodies are not JSON (Hyperliquid's info endpoint
    /// answers a refusal in plain text): the hook types every refusal, and DataFetch's own error is the fallback
    package static func send<Value: Decodable & Sendable>(
        _ url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [(field: String, value: String)] = [],
        session: any URLSessionProtocol,
        errorForResponse: @escaping @Sendable (HTTPURLResponse, Data?) -> (any Error)?
    ) async throws -> Value {
        try await openWithoutErrorType(session, url, method, body, headers, errorForResponse)
    }

    private static func openWithoutErrorType<Session: URLSessionProtocol, Value: Decodable & Sendable>(
        _ session: Session,
        _ url: URL,
        _ method: String,
        _ body: Data?,
        _ headers: [(field: String, value: String)],
        _ errorForResponse: @escaping @Sendable (HTTPURLResponse, Data?) -> (any Error)?
    ) async throws -> Value {
        try await DataFetch(urlSession: session, errorForResponse: errorForResponse).send(
            data: body,
            to: url,
            httpMethod: method,
            headers: headers.isEmpty ? nil : headers,
            locale: nil
        )
    }

    private static func open<Session: URLSessionProtocol, Value: Decodable & Sendable, Failure: Decodable & Error>(
        _ session: Session,
        _ url: URL,
        _ method: String,
        _ body: Data?,
        _ headers: [(field: String, value: String)],
        _ errorType: Failure.Type,
        _ errorForResponse: @escaping @Sendable (HTTPURLResponse, Data?) -> (any Error)?
    ) async throws -> Value {
        // DataFetch's own `post(data:to:headers:errorType:)` sends DELETE (FOSUtilities 0.20.0), so every call goes
        // through `send(data:to:httpMethod:…)` with its method named here.
        try await DataFetch(urlSession: session, errorForResponse: errorForResponse).send(
            data: body,
            to: url,
            httpMethod: method,
            headers: headers.isEmpty ? nil : headers,
            locale: nil,
            errorType: errorType
        )
    }
}

/// How many requests a client has made in the exchange's current window, counted in its fetch hook (AR69)
///
/// Kraken and Coinbase publish their limits rather than send them per response, so their clients count their own
/// requests against the published limit; the tally starts a new window at the first response after the last one
/// ended. Hyperliquid states its own count, so its client keeps none.
package final class RequestTally: @unchecked Sendable {
    private let lock = NSLock()
    private let window: Duration
    private var windowStart: Date?
    private var count = 0

    package init(window: Duration) {
        self.window = window
    }

    /// Notes one response at `now`
    package func note(at now: Date) {
        lock.withLock {
            roll(to: now)
            count += 1
        }
    }

    /// The requests made in the window holding `now`, and when the window ends
    package func reading(at now: Date) -> (count: Int, resetsAt: Date) {
        lock.withLock {
            roll(to: now)
            let start = windowStart ?? now
            return (count, start.addingTimeInterval(Self.seconds(window)))
        }
    }

    private func roll(to now: Date) {
        if let start = windowStart, now.timeIntervalSince(start) < Self.seconds(window) {
            return
        }
        windowStart = now
        count = 0
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let (seconds, attoseconds) = duration.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}

extension Date {
    /// The instant a feed's or an exchange's whole milliseconds since 1970 UTC name
    package init(wireMilliseconds milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    /// The nearest whole millisecond since 1970 UTC: a date decoded from a millisecond carries exactly that back
    package var wireMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
