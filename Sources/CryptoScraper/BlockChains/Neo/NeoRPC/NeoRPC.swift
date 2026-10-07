// NeoRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for a public Neo N3 node's JSON-RPC, `mainnet1.neo.coz.io`, keyless
///
/// Reads NEP-17 balances (`getnep17balances`) and transfers (`getnep17transfers`): NEO and GAS by their native
/// contracts' script hashes, and any other NEP-17 token by its own.
public struct NeoRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = NeoContract

    /// COZ's public MainNet node
    public static let endPoint: URL = .init(string: "https://mainnet1.neo.coz.io:443")!

    /// "Neo RPC"
    public let userReadableName: String = "Neo RPC"

    public init() {}

    /// The native contracts' script hashes, as the node's `getnativecontracts` states them (`NeoToken`, `GasToken`),
    /// by the placeholder addresses the chain gives the two coins
    static let nativeScriptHashes: [String: String] = [
        NeoChain.neoContractAddress: "0xef4073a0f2b305a38ec4050e4d3d28bc40ea63f5",
        NeoChain.gasContractAddress: "0xd2a4cff31913016155e38e474a2c06d08be276cf"
    ]

    /// The script hash the node reads `contract` by: a coin's native contract's, or a token's own
    static func scriptHash(of contract: NeoContract) -> String {
        nativeScriptHashes[contract.address] ?? contract.address.lowercased()
    }

    /// The contract a script hash names: a coin's placeholder for a native contract's, else the token's own
    static func contract(ofScriptHash hash: String) -> NeoContract {
        let hash = hash.lowercased()
        let placeholder = nativeScriptHashes.first { $0.value == hash }?.key
        return NeoContract(address: placeholder ?? hash)
    }
}

public enum NeoRPCResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// The contract is no NEP-17 token, so its balance is not read
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a balance of a contract that is no NEP-17 token"
        }
    }
}

extension NeoRPC {
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
                throw NeoRPCResponseError.requestFailed("\(error.code): \(error.message)")
            }
            guard let result else {
                throw NeoRPCResponseError.requestFailed("no result")
            }
            return result
        }
    }
}
