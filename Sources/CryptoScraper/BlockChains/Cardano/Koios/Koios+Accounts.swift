// Koios+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Koios {
    /// Returns the balance, in lovelace, of the given address; an address the ledger has never seen holds none
    ///
    /// - Parameter account: The Cardano address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: [AddressInfo] = try await Self.post("address_info", ["_addresses": [account.address]])

        return try AddressInfo.amount(response)
    }

    /// Returns ADA's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``KoiosResponseError/unknownToken`` for any other contract: a native asset's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw KoiosResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Koios {
    /// `address_info`'s answer: `[{ "address", "balance": "<lovelace>", "stake_address", "utxo_set": … }]`, empty for
    /// an address the ledger has never seen
    struct AddressInfo: Decodable, Sendable {
        let address: String
        let balance: String

        /// The balance in ADA's main contract, counted in lovelace, read by its digits; zero when none is listed
        static func amount(_ answer: [AddressInfo]) throws -> Amount<CardanoContract> {
            let coin = CardanoChain.default.mainContract!
            guard let info = answer.first else {
                return .init(quantity: 0, currency: coin)
            }
            guard let quantity = Int128(info.balance) else {
                throw KoiosResponseError.requestFailed("balance \(info.balance) is not a count of lovelace")
            }
            return .init(quantity: quantity, currency: coin)
        }
    }
}
