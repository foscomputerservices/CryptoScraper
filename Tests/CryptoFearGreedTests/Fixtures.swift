// Fixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoFearGreed
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The recorded responses, and a session that answers from them. Both files under Resources/AlternativeMe were
// recorded from api.alternative.me on 2026-10-07, keyless: fng-limit0.json (`/fng/?limit=0&format=json`, the whole
// history) at 14:56:35 UTC and fng-limit30.json (`/fng/?limit=30&format=json`) at 14:56:36 UTC. Each answers newest
// first, its first entry the day still being updated, the one that carries `time_until_update`.

enum Recorded {
    static func data(_ path: String) -> Data {
        // SwiftPM lays a `.copy("Resources")` folder at the bundle's root on one toolchain and inside `Resources/` on
        // another, so both places are tried.
        let base = Bundle.module.resourceURL!
        for candidate in [base.appendingPathComponent("Resources/\(path)"), base.appendingPathComponent(path)] {
            if let data = try? Data(contentsOf: candidate) { return data }
        }
        fatalError("No recorded fixture \(path) under \(base.path)")
    }

    static let whole = data("AlternativeMe/fng-limit0.json")
    static let lastThirty = data("AlternativeMe/fng-limit30.json")

    // The instant of the whole history's recording: the response's Date header.
    static let recordedAt = Date(timeIntervalSince1970: 1_791_384_995)       // 2026-10-07T14:56:35Z

    static let firstDay = Date(timeIntervalSince1970: 1_517_443_200)          // 2018-02-01
    static let lastFinalDay = Date(timeIntervalSince1970: 1_791_244_800)      // 2026-10-06
    static let inProgressDay = Date(timeIntervalSince1970: 1_791_331_200)     // 2026-10-07
    static let lastThirtyFirstDay = Date(timeIntervalSince1970: 1_788_825_600) // 2026-09-08

    // The response's rows as the publisher wrote them, newest first.
    static func rows(_ data: Data) -> [[String: Any]] {
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        return object["data"] as! [[String: Any]]
    }

    // The response with its rows replaced, the envelope kept.
    static func response(_ data: Data, rows: [[String: Any]]) -> Data {
        var object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["data"] = rows
        return try! JSONSerialization.data(withJSONObject: object)
    }
}

// The UTC midnight `days` after 1970-01-01.
func day(_ days: Int) -> Date {
    Date(timeIntervalSince1970: Double(days) * 86_400)
}

// A reply the recorded session gives.
struct Reply: Sendable {
    let status: Int
    let body: Data

    static func ok(_ body: Data) -> Reply { .init(status: 200, body: body) }
}

// A URLSessionProtocol that answers each request through `route`, notes every request, and never touches the
// network: the task it returns is an inert `data:` task.
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
            headerFields: ["Content-Type": "application/json"]
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

// Alternative.me answered from the whole recording as it would answer: `limit=0` the whole history, `limit=N` its
// newest N rows, the rows themselves untouched.
func alternativeMeRoute(_ request: URLRequest) -> Reply {
    let limit = request.query("limit").flatMap { Int($0) } ?? 0
    guard limit > 0 else { return .ok(Recorded.whole) }
    return .ok(Recorded.response(Recorded.whole, rows: Array(Recorded.rows(Recorded.whole).prefix(limit))))
}

func client(_ session: ReplaySession) -> AlternativeMeFearGreedClient {
    AlternativeMeFearGreedClient(session: session)
}

// A FearGreedHistoryStore in memory, the second conformer every retrieval test runs against.
actor MemoryStore: FearGreedHistoryStore {
    private var kept: [FearGreedDay] = []

    func lastDay() async throws -> FearGreedDay? {
        kept.last
    }

    func append(_ days: [FearGreedDay]) async throws {
        kept += days
    }

    func history() async throws -> [FearGreedDay] {
        kept
    }
}

// The two conformers of the store protocol each retrieval test runs against.
enum ContractStoreKind: String, CaseIterable, Sendable {
    case memory
    case file
}

// A fresh file in a fresh temporary directory per call, never removed by the tests (the system clears its
// temporary directory).
func temporaryFile() -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CryptoFearGreedTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent("alternative-me.jsonl")
}

func makeStore(_ kind: ContractStoreKind) -> any FearGreedHistoryStore {
    switch kind {
    case .memory: MemoryStore()
    case .file: FearGreedHistoryFileStore(file: temporaryFile())
    }
}
