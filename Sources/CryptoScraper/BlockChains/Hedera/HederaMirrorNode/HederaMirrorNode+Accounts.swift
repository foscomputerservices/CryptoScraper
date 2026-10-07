// HederaMirrorNode+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension HederaMirrorNode {
    /// Returns the balance, in tinybars, of the given account
    ///
    /// - Parameter account: The Hedera account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.get(
            Self.endPoint.appending(path: "accounts").appending(path: account.address)
                .appending(queryItems: [.init(name: "transactions", value: "false")])
        )

        return response.amount()
    }

    /// Returns HBAR's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``HederaMirrorNodeResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw HederaMirrorNodeResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension HederaMirrorNode {
    /// `/api/v1/accounts/{id}`: `{ "account": …, "balance": { "balance": <tinybars>, … }, … }`
    struct AccountResponse: Decodable, Sendable {
        let account: String
        let balance: Balance

        struct Balance: Decodable, Sendable {
            let balance: Int64
        }

        /// The balance in HBAR's main contract, counted in tinybars
        func amount() -> Amount<HederaContract> {
            .init(quantity: Int128(balance.balance), currency: HederaChain.default.mainContract)
        }
    }
}
