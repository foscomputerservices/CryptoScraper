// Horizon.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Horizon, Stellar's public API, `horizon.stellar.org`, keyless
///
/// Reads XLM: an account's native balance (`/accounts/{id}`) and its payments (`/accounts/{id}/payments`). An
/// issued asset's balance is not read.
public struct Horizon: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = StellarContract

    /// The Stellar Development Foundation's public Horizon
    public static let endPoint: URL = .init(string: "https://horizon.stellar.org")!

    /// "Horizon"
    public let userReadableName: String = "Horizon"

    public init() {}
}

public enum HorizonResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// An issued asset's balance is not read by this scanner, only XLM's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read an issued asset's balance on Stellar; only XLM's is read"
        }
    }
}

extension Horizon {
    /// A GET of `url`, its answer as `Result`; Horizon answers `application/hal+json`, so the media type is not
    /// checked, and a problem answer is thrown as ``Problem``
    static func get<Result: Decodable & Sendable>(_ url: URL) async throws -> Result {
        try await DataFetch<URLSession>.default.send(
            to: url, httpMethod: "GET", headers: nil, locale: nil, checkReceivedMimeType: false, errorType: Problem.self
        )
    }

    /// Horizon's problem answer: `{ "title": …, "status": 404, "detail": … }`
    struct Problem: Error, Decodable, Sendable {
        let title: String
        let status: Int
        let detail: String?

        var horizonError: HorizonResponseError {
            .requestFailed("\(status) \(title)" + (detail.map { ": " + $0 } ?? ""))
        }
    }

    /// An amount as Horizon writes it, a decimal string with up to 7 fraction digits, in stroops; `nil` when it is
    /// not one
    static func stroops(_ text: String) -> Int128? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let whole = Int128(parts[0]) else {
            return nil
        }
        let fraction = parts.count == 2 ? parts[1] : ""
        guard fraction.count <= 7, fraction.allSatisfy(\.isASCII), fraction.allSatisfy(\.isNumber) else {
            return nil
        }
        let padded = fraction + String(repeating: "0", count: 7 - fraction.count)
        guard let fractionStroops = Int128(padded) else {
            return nil
        }
        return whole * 10_000_000 + fractionStroops
    }
}
