// SolanaRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Solana's public JSON-RPC, `api.mainnet-beta.solana.com`, keyless
///
/// Reads SOL: an account's balance (`getBalance`) and its transactions (`getSignaturesForAddress`, then
/// `getTransaction` for each). A token's balance is not read.
public struct SolanaRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = SolanaContract

    /// Solana's public mainnet-beta endpoint
    public static let endPoint: URL = .init(string: "https://api.mainnet-beta.solana.com")!

    /// "Solana RPC"
    public let userReadableName: String = "Solana RPC"

    public init() {}
}

public enum SolanaRPCResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner, only SOL's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a token's balance on Solana through its JSON-RPC; only SOL's is read"
        }
    }
}

extension SolanaRPC {
    /// One JSON-RPC 2.0 call: `method` with `params`, posted to ``endPoint``
    static func call<Result: Decodable & Sendable>(_ method: String, _ params: [Any]) async throws -> Result {
        let body = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1, "method": method, "params": params
        ] as [String: Any])
        let response: Response<Result> = try await DataFetch<URLSession>.default.send(
            data: body, to: endPoint, httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )
        return try response.value()
    }

    /// A JSON-RPC 2.0 answer: its `result`, or its `error`, thrown in the node's words
    struct Response<Result: Decodable & Sendable>: Decodable, Sendable {
        let result: Result?
        let error: Failure?

        struct Failure: Decodable, Sendable {
            let code: Int
            let message: String
        }

        func value() throws -> Result {
            if let error {
                throw SolanaRPCResponseError.requestFailed("\(error.code): \(error.message)")
            }
            guard let result else {
                throw SolanaRPCResponseError.requestFailed("no result")
            }
            return result
        }
    }
}
