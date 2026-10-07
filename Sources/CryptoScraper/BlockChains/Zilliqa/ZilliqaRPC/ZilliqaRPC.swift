// ZilliqaRPC.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Zilliqa's public JSON-RPC, `api.zilliqa.com`, keyless
///
/// Reads ZIL: an address's balance (`GetBalance`, asked with the address's 20 bytes in hex). The RPC lists no
/// account's transactions and ViewBlock, which does, needs a key, so ``getTransactions(forAccount:)`` throws; a
/// ZRC-2 token's balance is not read.
public struct ZilliqaRPC: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = ZilliqaContract

    /// Zilliqa's public mainnet API
    public static let endPoint: URL = .init(string: "https://api.zilliqa.com")!

    /// "Zilliqa RPC"
    public let userReadableName: String = "Zilliqa RPC"

    public init() {}
}

public enum ZilliqaRPCResponseError: Error {
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
            return "Unable to read a token's balance on Zilliqa; only ZIL's is read"
        }
    }
}

public extension ZilliqaRPC {
    /// Returns the balance, in Qa, of the given address; an address the ledger has not created holds none
    ///
    /// - Parameter account: The Zilliqa address to query the balance for
    /// - Throws: ``ZilliqaRPCResponseError/unknownContract(_:)`` when `account` is not a bech32 `zil1` address (the
    ///   coin's placeholder among them); ``ZilliqaRPCResponseError/requestFailed(_:)`` for any error but an
    ///   address not created, or for no balance in Qa
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        guard let bytes = ZilliqaContract.bytes(bech32: account.address) else {
            throw ZilliqaRPCResponseError.unknownContract(account.address)
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": "1", "method": "GetBalance",
            "params": [bytes.map { String(format: "%02x", $0) }.joined()]
        ] as [String: Any])
        let response: BalanceResponse = try await DataFetch<URLSession>.default.send(
            data: body, to: Self.endPoint, httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )

        return try response.amount()
    }

    /// Returns ZIL's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``ZilliqaRPCResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw ZilliqaRPCResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// The RPC lists no account's transactions, so none are read
    ///
    /// - Throws: ``ZilliqaRPCResponseError/requestFailed(_:)``, always
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw ZilliqaRPCResponseError.requestFailed(Self.noTransactions)
    }

    /// The RPC lists no account's transactions, so no answer of it holds any
    ///
    /// - Throws: ``ZilliqaRPCResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw ZilliqaRPCResponseError.requestFailed(Self.noTransactions)
    }
}

extension ZilliqaRPC {
    static var noTransactions: String {
        "Zilliqa's RPC lists no account's transactions, and ViewBlock, which does, needs a key"
    }

    /// The RPC's code and words for an address the ledger has not created, which holds no ZIL
    static let accountNotCreated = (code: -5, message: "Account is not created")

    /// `GetBalance`'s answer: `{ "result": { "balance": "<Qa>", "nonce": … } }`, or `{ "error": { "code", "message" }
    /// }`
    struct BalanceResponse: Decodable, Sendable {
        let result: Balance?
        let error: Failure?

        struct Balance: Decodable, Sendable {
            let balance: String
        }

        struct Failure: Decodable, Sendable {
            let code: Int
            let message: String
        }

        /// The balance in ZIL's main contract, counted in Qa; zero for an address not created; any other error thrown
        /// in the RPC's words
        func amount() throws -> Amount<ZilliqaContract> {
            let coin = ZilliqaChain.default.mainContract!
            if let error {
                let notCreated = ZilliqaRPC.accountNotCreated
                guard error.code == notCreated.code, error.message == notCreated.message else {
                    throw ZilliqaRPCResponseError.requestFailed("\(error.code): \(error.message)")
                }
                return .init(quantity: 0, currency: coin)
            }
            guard let text = result?.balance, let quantity = Int128(text) else {
                throw ZilliqaRPCResponseError.requestFailed("no balance in Qa")
            }
            return .init(quantity: quantity, currency: coin)
        }
    }
}
