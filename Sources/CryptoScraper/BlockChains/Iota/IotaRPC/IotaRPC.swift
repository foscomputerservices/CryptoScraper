// IotaRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A ``CryptoScanner`` implementation for IOTA's public JSON-RPC, `api.mainnet.iota.cafe`, keyless
///
/// Reads IOTA: an address's balance (`iotax_getBalance`) and the transaction blocks sent from it and to it
/// (`iotax_queryTransactionBlocks`), each by its IOTA balance change. A token's balance is not read.
public struct IotaRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = IotaContract

    /// The IOTA Foundation's public mainnet node
    public static let endPoint: URL = .init(string: "https://api.mainnet.iota.cafe")!

    /// "IOTA RPC"
    public let userReadableName: String = "IOTA RPC"

    public init() {}
}

public enum IotaRPCResponseError: Error {
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
            return "Unable to read a token's balance on IOTA; only IOTA's is read"
        }
    }
}

extension IotaRPC {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = IotaContract

        let hash: String
        let fromContract: IotaContract?
        let toContract: IotaContract?
        let amount: Amount<IotaContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<IotaContract>?
        var gasUsed: Amount<IotaContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension IotaRPC {
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
                throw IotaRPCResponseError.requestFailed("\(error.code): \(error.message)")
            }
            guard let result else {
                throw IotaRPCResponseError.requestFailed("no result")
            }
            return result
        }
    }

    /// IOTA's coin type, as the ledger names it: `0x2::iota::IOTA`
    static let coinType = "0x2::iota::IOTA"
}
