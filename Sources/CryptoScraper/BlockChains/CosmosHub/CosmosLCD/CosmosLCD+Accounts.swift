// CosmosLCD+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension CosmosLCD {
    /// Returns the balance of the given address in the chain's coin, counted in its denom; zero when the address holds
    /// none
    ///
    /// - Parameter account: The address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalancesResponse = try await endPoint
            .appending(path: "cosmos").appending(path: "bank").appending(path: "v1beta1").appending(path: "balances")
            .appending(path: account.address)
            .appending(queryItems: [.init(name: "pagination.limit", value: "1000")])
            .fetch()

        return try response.amount(of: denom)
    }

    /// Returns the coin's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``CosmosLCDResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw CosmosLCDResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension CosmosLCD {
    /// `/cosmos/bank/v1beta1/balances/{address}`: `{ "balances": [ { "denom", "amount" } ], "pagination": … }`, every
    /// denom the address holds, the chain's coin among them when it holds any
    struct BalancesResponse: Decodable, Sendable {
        let balances: [Coin]

        /// The balance in the chain's main contract, counted in `denom`; zero when no entry names it
        func amount(of denom: String) throws -> Amount<Contract> {
            let amount = balances.first { $0.denom == denom }?.amount ?? "0"
            guard let quantity = Int128(amount) else {
                throw CosmosLCDResponseError.requestFailed("balance \(amount) is not a count of \(denom)")
            }
            return .init(quantity: quantity, currency: Contract.Chain.default.mainContract)
        }
    }

    /// One coin as the Cosmos SDK writes it: its denom and its amount, a count of the denom in decimal
    struct Coin: Decodable, Sendable {
        let denom: String
        let amount: String
    }
}
