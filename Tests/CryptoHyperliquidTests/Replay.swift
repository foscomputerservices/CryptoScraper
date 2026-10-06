// Replay.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FOSFoundation

// A URLSessionProtocol that answers each request from the recordings through `route`, notes every request, and never
// touches the network: the task it returns is an inert `data:` task. Each recording's first line is a `//` header
// naming its origin (recorded, documentation-derived or constructed); the replay serves the body below it.

struct Reply: Sendable {
    let status: Int
    let body: Data
    let headers: [String: String]
    /// A transport failure instead of an answer: the session throws it
    var failure: URLError? = nil

    static func ok(_ body: Data) -> Reply { .init(status: 200, body: body, headers: [:]) }
    static func failing(_ failure: URLError) -> Reply { .init(status: 0, body: Data(), headers: [:], failure: failure) }
}

final class ReplaySession: URLSessionProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var noted: [URLRequest] = []
    private let route: @Sendable (URLRequest, Int) -> Reply

    init(route: @escaping @Sendable (URLRequest, Int) -> Reply) {
        self.route = route
    }

    var requests: [URLRequest] {
        lock.withLock { noted }
    }

    func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        let index = lock.withLock {
            noted.append(request)
            return noted.count - 1
        }
        let reply = route(request, index)
        if let failure = reply.failure {
            completionHandler(nil, nil, failure)
            return Self.inert.dataTask(with: URL(string: "data:,")!)
        }
        var headers = ["Content-Type": "application/json;charset=UTF-8"]
        headers.merge(reply.headers) { _, new in new }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: headers)
        completionHandler(reply.body, response, nil)
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("ReplaySession is made with a route")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

enum Recording {
    // A recording's raw bytes, at either place SwiftPM lays a copied resource folder.
    static func data(_ path: String) -> Data {
        let base = Bundle.module.resourceURL!
        for candidate in [base.appendingPathComponent("Resources/\(path)"), base.appendingPathComponent(path)] {
            if let data = try? Data(contentsOf: candidate) { return data }
        }
        fatalError("No recording \(path) under \(base.path)")
    }

    // The body of a recording, its `//` header lines and the recorder's one closing newline dropped.
    static func body(_ path: String) -> Data {
        let text = String(decoding: data(path), as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).drop { $0.hasPrefix("//") }
        if lines.last == "" { lines = lines.dropLast() }
        return Data(lines.joined(separator: "\n").utf8)
    }

    static func json(_ path: String) -> Any {
        try! JSONSerialization.jsonObject(with: body(path), options: [.fragmentsAllowed])
    }
}

extension URLRequest {
    var jsonBody: [String: Any] {
        guard let body = httpBody else { return [:] }
        return (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
    }

    var bodyText: String {
        httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    func query(_ name: String) -> String? {
        URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

/// The shared error a call threw (nil when it threw none or threw another type): what a client hands up is C30's
func sharedError<Result>(_ call: () async throws -> Result) async -> ExchangeClientError? {
    do {
        _ = try await call()
        return nil
    } catch {
        return error as? ExchangeClientError
    }
}

extension ExchangeClientError {
    /// The case alone, for a test that asserts the meaning and not the exchange's words
    var meaning: String {
        switch self {
        case .refused: "refused"
        case .rateLimited: "rateLimited"
        case .unauthorized: "unauthorized"
        case .unreachable: "unreachable"
        case .malformedResponse: "malformedResponse"
        case .notOffered: "notOffered"
        }
    }
}
