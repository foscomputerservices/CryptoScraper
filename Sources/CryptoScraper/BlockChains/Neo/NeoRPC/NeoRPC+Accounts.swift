// NeoRPC+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension NeoRPC {
    /// Returns the account's NEO, the chain's coin, indivisible
    ///
    /// - Parameter account: The Neo account to query the balance for
    /// - Throws: ``NeoRPCResponseError/requestFailed(_:)`` when the node answers with an error or no result, or with an
    ///   amount that is not a count of base units
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        try await getBalance(forToken: account.chain.mainContract, forAccount: account)
    }

    /// Returns the account's balance of `contract`, in its base units: NEO, GAS, or any NEP-17 token by its script
    /// hash; zero when the node lists none of it for the account
    ///
    /// - Throws: ``NeoRPCResponseError/unknownToken`` when `contract` is an account, not a coin or a script hash;
    ///   ``NeoRPCResponseError/requestFailed(_:)`` when the node answers with an error or no result, or with an
    ///   amount that is not a count of base units
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard Self.nativeScriptHashes[contract.address] != nil || contract.address.hasPrefix("0x") else {
            throw NeoRPCResponseError.unknownToken
        }
        let response: BalancesResponse = try await Self.call("getnep17balances", [account.address])

        return try response.amount(of: contract)
    }
}

extension NeoRPC {
    /// `getnep17balances`'s result: `{ "address": …, "balance": [{ "assethash": …, "amount": "<base units>" }] }`
    struct BalancesResponse: Decodable, Sendable {
        let address: String
        let balance: [Balance]

        struct Balance: Decodable, Sendable {
            let assethash: String
            let amount: String
            let symbol: String?
        }

        /// The balance of `contract` matched by its script hash, never by a symbol; zero when the node lists none
        func amount(of contract: NeoContract) throws -> Amount<NeoContract> {
            let hash = NeoRPC.scriptHash(of: contract)
            guard let row = balance.first(where: { $0.assethash.lowercased() == hash }) else {
                return .init(quantity: 0, currency: contract)
            }
            guard let quantity = Int128(row.amount) else {
                throw NeoRPCResponseError.requestFailed("amount \(row.amount) is not a count of base units")
            }
            return .init(quantity: quantity, currency: contract)
        }
    }
}
