// ResponseCapture.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// FOSFoundation's public fetch decodes a failed response into its errorType and discards the HTTP status and the
// headers; the one door that returns a header is `package` to FOSUtilities. A limit response must surface as a
// typed case with Binance's Retry-After, so the client hands DataFetch a session that wraps the caller's session and
// notes the status and the Retry-After of the one response it carries. The request still goes through
// DataFetch's fetch with its errorType; nothing here sends or decodes.

final class ResponseCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedStatus: Int?
    private var capturedRetryAfter: String?

    var status: Int? {
        lock.withLock { capturedStatus }
    }

    // Binance sends Retry-After as whole seconds.
    var retryAfter: Duration? {
        lock.withLock { capturedRetryAfter }
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map { .seconds($0) }
    }

    func record(_ response: URLResponse?) {
        guard let http = response as? HTTPURLResponse else { return }
        lock.withLock {
            capturedStatus = http.statusCode
            capturedRetryAfter = http.value(forHTTPHeaderField: "Retry-After")
        }
    }
}

struct CapturingSession: URLSessionProtocol {
    let base: any URLSessionProtocol
    let capture: ResponseCapture

    func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        base.dataTask(with: url) { [capture] data, response, error in
            capture.record(response)
            completionHandler(data, response, error)
        }
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        base.dataTask(with: request) { [capture] data, response, error in
            capture.record(response)
            completionHandler(data, response, error)
        }
    }

    static func session(config: URLSessionConfiguration) -> Self {
        Self(base: URLSession.session(config: config), capture: ResponseCapture())
    }
}
