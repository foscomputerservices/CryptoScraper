// TzKT+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension TzKT {
    /// Returns the balance, in mutez, of the given account
    ///
    /// - Parameter account: The Tezos account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.endPoint.appending(path: "accounts")
            .appending(path: account.address)
            .fetch()

        return try response.amount()
    }

    /// Returns XTZ's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``TzKTResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw TzKTResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension TzKT {
    /// `/v1/accounts/{address}`: `{ "type": …, "address": …, "balance": <mutez>, … }`; an account the chain has
    /// never seen answers `"type": "empty"` and no balance
    struct AccountResponse: Decodable, Sendable {
        let type: String
        let address: String
        let balance: Int64?

        /// The balance in XTZ's main contract, counted in mutez
        func amount() throws -> Amount<TezosContract> {
            .init(quantity: Int128(balance ?? 0), currency: TezosChain.default.mainContract)
        }
    }
}
