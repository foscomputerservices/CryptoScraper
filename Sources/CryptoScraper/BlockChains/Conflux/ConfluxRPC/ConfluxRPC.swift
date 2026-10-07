// ConfluxRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Conflux core space's public JSON-RPC, `main.confluxrpc.com`, keyless
///
/// Reads CFX: an address's balance (`cfx_getBalance`). The node lists no address's transactions, and
/// ConfluxScan's list moved (it answered 301 when recorded), so ``getTransactions(forAccount:)`` throws; a token's
/// balance is not read.
public struct ConfluxRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = ConfluxContract

    /// Conflux's public core space node
    public static let endPoint: URL = .init(string: "https://main.confluxrpc.com")!

    /// "Conflux RPC"
    public let userReadableName: String = "Conflux RPC"

    public init() {}
}

public enum ConfluxRPCResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a token's balance on Conflux; only CFX's is read"
        }
    }
}

extension ConfluxRPC {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = ConfluxContract

        let hash: String
        let fromContract: ConfluxContract?
        let toContract: ConfluxContract?
        let amount: Amount<ConfluxContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<ConfluxContract>?
        var gasUsed: Amount<ConfluxContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension ConfluxRPC {
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
                throw ConfluxRPCResponseError.requestFailed("\(error.code): \(error.message)")
            }
            guard let result else {
                throw ConfluxRPCResponseError.requestFailed("no result")
            }
            return result
        }
    }

    /// A quantity as the node writes it, `0x` and hex digits; `nil` when it is not one
    static func quantity(hex text: String) -> Int128? {
        guard text.hasPrefix("0x"), text.count > 2 else {
            return nil
        }
        return Int128(text.dropFirst(2), radix: 16)
    }

    static let noTransactions = "Conflux's node lists no address's transactions, and ConfluxScan's list moved"
}
