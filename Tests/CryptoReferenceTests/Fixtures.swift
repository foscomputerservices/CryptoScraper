// Fixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoReference
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Resources/CoinMarketCap/listings-latest.json is 15 rows of the POC's categories.json (CoinMarketCap's
// listings/latest, fetched 2026-09-13T20:17:54Z) re-wrapped as the API's documented envelope with the API's own
// field names: ranks 1 to 10, both MEME, 币安人生, USDf and RAIN (not counted in the market cap).
// error-key-missing.json is the documented envelope for error 1002.

enum Recorded {
    static func data(_ path: String) -> Data {
        // SwiftPM lays a `.copy("Resources")` folder at the bundle's root on one toolchain and inside `Resources/` on
        // another (Xcode 26.6's puts it one level deeper than Swift 6.4's), so both places are tried.
        let base = Bundle.module.resourceURL!
        for candidate in [base.appendingPathComponent("Resources/\(path)"), base.appendingPathComponent(path)] {
            if let data = try? Data(contentsOf: candidate) { return data }
        }
        fatalError("No recorded fixture \(path) under \(base.path)")
    }

    static let listings = data("CoinMarketCap/listings-latest.json")
    static let keyMissing = data("CoinMarketCap/error-key-missing.json")

    // The listing's rows from `start` (1-based), at most `limit`, in the same envelope.
    static func listings(start: Int, limit: Int) -> Data {
        var envelope = try! JSONSerialization.jsonObject(with: listings) as! [String: Any]
        let rows = envelope["data"] as! [Any]
        let from = min(start - 1, rows.count)
        envelope["data"] = Array(rows[from..<min(from + limit, rows.count)])
        return try! JSONSerialization.data(withJSONObject: envelope)
    }
}

func symbol(_ text: String) -> AssetSymbol {
    try! AssetSymbol(validating: text)
}

struct Reply: Sendable {
    let status: Int
    let body: Data
}

// A URLSessionProtocol that answers from the recorded files, notes every request, and never touches the network.
final class ReplaySession: URLSessionProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var noted: [URLRequest] = []
    private let route: @Sendable (URLRequest) -> Reply

    init(route: @escaping @Sendable (URLRequest) -> Reply) {
        self.route = route
    }

    var requests: [URLRequest] {
        lock.withLock { noted }
    }

    func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        lock.withLock { noted.append(request) }
        let reply = route(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json; charset=utf-8"]
        )
        completionHandler(reply.body, response, nil)
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("ReplaySession is made with a route")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

extension URLRequest {
    func query(_ name: String) -> String? {
        URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

// The listing answered page by page from the recording, by `start` and `limit`.
func listingRoute(_ request: URLRequest) -> Reply {
    Reply(status: 200, body: Recorded.listings(start: Int(request.query("start")!)!, limit: Int(request.query("limit")!)!))
}
