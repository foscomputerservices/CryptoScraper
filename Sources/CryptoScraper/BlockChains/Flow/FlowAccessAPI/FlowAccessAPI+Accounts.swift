// FlowAccessAPI+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension FlowAccessAPI {
    /// Returns the balance of the given account, counted in FLOW's base count (8 decimals)
    ///
    /// - Parameter account: The Flow account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.endPoint
            .appending(path: "accounts").appending(path: account.address)
            .fetch()

        return try response.amount()
    }

    /// Returns FLOW's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``FlowAccessAPIResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw FlowAccessAPIResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// The Access API lists no account's transactions, so none are read
    ///
    /// - Throws: ``FlowAccessAPIResponseError/requestFailed(_:)``, always
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw FlowAccessAPIResponseError.requestFailed(Self.noTransactions)
    }

    /// No answer of the Access API holds an account's transactions
    ///
    /// - Throws: ``FlowAccessAPIResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw FlowAccessAPIResponseError.requestFailed(Self.noTransactions)
    }
}

extension FlowAccessAPI {
    static let noTransactions = "Flow's Access API lists no account's transactions"

    /// `/v1/accounts/{address}`: `{ "address": "<16 hex digits>", "balance": "<base count>", … }`
    struct AccountResponse: Decodable, Sendable {
        let address: String
        let balance: String

        /// The balance in FLOW's main contract, counted in its base count, read by its digits
        func amount() throws -> Amount<FlowContract> {
            guard let quantity = Int128(balance) else {
                throw FlowAccessAPIResponseError.requestFailed("balance \(balance) is not a count of FLOW's base count")
            }
            return .init(quantity: quantity, currency: FlowChain.default.mainContract)
        }
    }
}
