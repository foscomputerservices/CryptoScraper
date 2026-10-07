// MultiversXAPI+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension MultiversXAPI {
    /// Returns the balance, in EGLD's atomic units, of the given account
    ///
    /// - Parameter account: The MultiversX address to query the balance for
    /// - Throws: ``MultiversXAPIResponseError/requestFailed(_:)`` when the balance is not a count of atomic units
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.endPoint
            .appending(path: "accounts").appending(path: account.address)
            .fetch()

        return try response.amount()
    }

    /// Returns EGLD's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``MultiversXAPIResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw MultiversXAPIResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension MultiversXAPI {
    /// `/accounts/{address}`: `{ "address": …, "balance": "<atomic units>", "nonce": …, … }`
    struct AccountResponse: Decodable, Sendable {
        let address: String
        let balance: String

        /// The balance in EGLD's main contract, counted in its atomic units, read by its digits
        func amount() throws -> Amount<MultiversXContract> {
            guard let quantity = Int128(balance) else {
                throw MultiversXAPIResponseError.requestFailed("balance \(balance) is not a count of EGLD's atomic units")
            }
            return .init(quantity: quantity, currency: MultiversXChain.default.mainContract)
        }
    }
}
