// Hiro+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Hiro {
    /// Returns the balance, in microSTX, of the given principal
    ///
    /// - Parameter account: The Stacks principal to query the balance for
    /// - Throws: ``HiroResponseError/requestFailed(_:)`` when the balance is not a count of microSTX
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalancesResponse = try await Self.endPoint
            .appending(path: "address").appending(path: account.address).appending(path: "balances")
            .fetch()

        return try response.amount()
    }

    /// Returns STX's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``HiroResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw HiroResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Hiro {
    /// `/address/{principal}/balances`: `{ "stx": { "balance": "<microSTX>", … }, "fungible_tokens": …, … }`
    struct BalancesResponse: Decodable, Sendable {
        let stx: STX

        struct STX: Decodable, Sendable {
            let balance: String
        }

        /// The balance in STX's main contract, counted in microSTX, read by its digits
        func amount() throws -> Amount<StacksContract> {
            guard let quantity = Int128(stx.balance) else {
                throw HiroResponseError.requestFailed("balance \(stx.balance) is not a count of microSTX")
            }
            return .init(quantity: quantity, currency: StacksChain.default.mainContract)
        }
    }
}
