// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for the identity PR's re-projected suite of the Fear and Greed client (AR14's second channel,
// step 6), projected from the documents alone. Each maps one call the projected file writes onto what the code and
// the target's recordings declare: wiring only, never a behavior. No assertion of a projected file is edited; a red
// that is not a defect is disabled in place with its classification as the reason.

import CryptoFearGreed
import FOSFoundation
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The recorded Alternative.me answers by the names the projected file gives them
enum RecordedAlternativeMe {
    /// The projected name of each recording this target holds, and its file under `Resources/`
    private static let files = [
        "fng-limit-0": "AlternativeMe/fng-limit0.json",
        "fng-limit-30": "AlternativeMe/fng-limit30.json"
    ]

    /// A session answering every request with the named recording, noting each request's URL under the asking test
    static func session(answering recording: String) -> ReplaySession {
        guard let file = files[recording] else {
            preconditionFailure("No recording named \(recording) in CryptoFearGreedTests")
        }
        let body = Recorded.data(file)
        return ReplaySession { request in
            note(request.url)
            return .ok(body)
        }
    }

    /// The URL of the last request the running test's recorded session was asked
    static var lastRequestURL: URL? {
        asked.withLock { $0[Test.current?.id.description ?? ""] }
    }

    private static let asked = Locked<[String: URL]>([:])

    private static func note(_ url: URL?) {
        guard let url else { return }
        asked.withLock { $0[Test.current?.id.description ?? ""] = url }
    }
}

/// A value behind a lock, for the recorded sessions' notes
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.withLock { body(&value) }
    }
}

/// The POC's vector of Fear and Greed days: it lives in fosline (`poc/vectors/sentiment/`), never in this public
/// package, so there is nothing here to load
enum POCVector {
    struct NotInThisPackage: Error {}

    static func fearGreedDays() throws -> [FearGreedDay] {
        throw NotInThisPackage()
    }
}
