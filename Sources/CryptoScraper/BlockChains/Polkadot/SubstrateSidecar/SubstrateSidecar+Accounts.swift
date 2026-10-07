// SubstrateSidecar+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension SubstrateSidecar {
    /// Returns the free balance of the given account, counted in planck
    ///
    /// - Parameter account: The SS58 account to query the balance for
    /// - Throws: ``SubstrateSidecarResponseError/requestFailed(_:)`` when the free balance is not a count of planck
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceInfoResponse = try await endPoint
            .appending(path: "accounts").appending(path: account.address).appending(path: "balance-info")
            .fetch()

        return try response.amount()
    }

    /// Returns the coin's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``SubstrateSidecarResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw SubstrateSidecarResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// The sidecar lists no account's transactions, so none are read
    ///
    /// - Throws: ``SubstrateSidecarResponseError/requestFailed(_:)``, always: the sidecar reads a node's state, not
    ///   an account's history
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw SubstrateSidecarResponseError.requestFailed(Self.noTransactions)
    }

    /// The sidecar lists no account's transactions, so no answer of it holds any
    ///
    /// - Throws: ``SubstrateSidecarResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw SubstrateSidecarResponseError.requestFailed(Self.noTransactions)
    }
}

extension SubstrateSidecar {
    static var noTransactions: String { "the Substrate API Sidecar lists no account's transactions" }

    /// `/accounts/{address}/balance-info`: `{ "at": { "hash", "height" }, "tokenSymbol", "free", "reserved",
    /// "frozen", "transferable", "locks" }`, each a count of planck in decimal
    struct BalanceInfoResponse: Decodable, Sendable {
        let tokenSymbol: String
        let free: String

        /// The free balance in the chain's main contract, counted in planck
        func amount() throws -> Amount<Contract> {
            guard let quantity = Int128(free) else {
                throw SubstrateSidecarResponseError.requestFailed("balance \(free) is not a count of planck")
            }
            return .init(quantity: quantity, currency: Contract.Chain.default.mainContract)
        }
    }
}
