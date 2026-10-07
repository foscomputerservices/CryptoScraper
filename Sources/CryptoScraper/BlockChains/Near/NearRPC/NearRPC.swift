// NearRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for NEAR's public JSON-RPC, `rpc.mainnet.near.org`, keyless, with NearBlocks'
/// keyless API, `api.nearblocks.io`, for an account's transactions
///
/// Reads NEAR: an account's balance (`query` with `view_account`) and the receipts NearBlocks lists for it
/// (`/v1/account/{id}/txns`). A token's balance is not read.
public struct NearRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = NearContract

    /// NEAR's public mainnet RPC
    public static let endPoint: URL = .init(string: "https://rpc.mainnet.near.org")!

    /// "NEAR RPC"
    public let userReadableName: String = "NEAR RPC"

    public init() {}
}

public enum NearRPCResponseError: Error {
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
            return "Unable to read a token's balance on NEAR; only NEAR's is read"
        }
    }
}

extension NearRPC {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = NearContract

        let hash: String
        let fromContract: NearContract?
        let toContract: NearContract?
        let amount: Amount<NearContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<NearContract>?
        var gasUsed: Amount<NearContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension NearRPC {
    /// NearBlocks' public API, the indexer the RPC lacks
    static let indexer: URL = .init(string: "https://api.nearblocks.io")!

    /// One JSON-RPC 2.0 call: `method` with `params`, posted to ``endPoint``
    static func call<Result: Decodable & Sendable>(_ method: String, _ params: [String: Any]) async throws -> Result {
        let body = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": "fos", "method": method, "params": params
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
            let name: String?
            let message: String?
            let cause: Cause?

            struct Cause: Decodable, Sendable {
                let name: String
            }
        }

        func value() throws -> Result {
            if let error {
                let words = [error.name, error.cause?.name, error.message].compactMap { $0 }
                throw NearRPCResponseError.requestFailed(words.joined(separator: ": "))
            }
            guard let result else {
                throw NearRPCResponseError.requestFailed("no result")
            }
            return result
        }
    }

    /// A count of yoctoNEAR as NearBlocks writes it, a JSON number, sometimes in exponent form (`7.03249476875e+21`):
    /// read through `Decimal`, exactly as written; `nil` when it is not a whole number
    static func yocto(_ number: Decimal) -> Int128? {
        var rounded = Decimal()
        var value = number
        NSDecimalRound(&rounded, &value, 0, .plain)
        guard rounded == number else {
            return nil
        }
        return Int128(number.description)
    }
}
