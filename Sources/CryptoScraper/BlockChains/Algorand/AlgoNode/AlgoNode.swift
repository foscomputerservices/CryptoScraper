// AlgoNode.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for AlgoNode's public Algorand node and indexer, keyless
///
/// Reads ALGO: an account's balance (the node's `/v2/accounts/{address}`) and its transactions (the indexer's
/// `/v2/accounts/{address}/transactions`), and a standard asset's own statement of its decimals (the node's
/// `/v2/assets/{id}`, ``getInfo(forToken:)``). An asset's balance is not read.
public struct AlgoNode: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = AlgorandContract

    /// AlgoNode's public MainNet node
    public static let endPoint: URL = .init(string: "https://mainnet-api.algonode.cloud/v2")!

    /// AlgoNode's public MainNet indexer
    static let indexerEndPoint: URL = .init(string: "https://mainnet-idx.algonode.cloud/v2")!

    /// "AlgoNode"
    public let userReadableName: String = "AlgoNode"

    public init() {}
}

public enum AlgoNodeResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A standard asset's balance is not read by this scanner, only ALGO's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a standard asset's balance on Algorand; only ALGO's is read"
        }
    }
}

extension AlgoNode {
    /// The node's and the indexer's refusal: `{ "message": … }`
    struct Refusal: Error, Decodable, Sendable {
        let message: String

        var algoNodeError: AlgoNodeResponseError {
            .requestFailed(message)
        }
    }

    /// A GET of `url`, its answer as `Result`, a refusal thrown in the node's words
    static func get<Result: Decodable & Sendable>(_ url: URL) async throws -> Result {
        do {
            return try await url.fetch(errorType: Refusal.self)
        } catch let refusal as Refusal {
            throw refusal.algoNodeError
        }
    }
}
