// ICPRosetta+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension ICPRosetta {
    /// Returns the balance, in e8s, of the given account identifier
    ///
    /// - Parameter account: The account identifier to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.post(
            "account/balance", ["account_identifier": ["address": account.address]]
        )

        return try response.amount()
    }

    /// Returns ICP's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``ICPRosettaResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw ICPRosettaResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension ICPRosetta {
    /// `/account/balance`: `{ "block_identifier", "balances": [<amount>] }`
    struct BalanceResponse: Decodable, Sendable {
        let balances: [RosettaAmount]

        /// The balance in ICP's main contract, counted in e8s
        func amount() throws -> Amount<InternetComputerContract> {
            guard let balance = balances.first else {
                throw ICPRosettaResponseError.requestFailed("no balance")
            }
            return try .init(quantity: balance.e8s(), currency: InternetComputerChain.default.mainContract)
        }
    }
}
