// ConfluxRPC+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension ConfluxRPC {
    /// Returns the balance, in drip, of the given address
    ///
    /// - Parameter account: The Conflux core space address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let result: String = try await Self.call("cfx_getBalance", [account.cip37Address])

        return try Self.balance(result)
    }

    /// Returns CFX's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``ConfluxRPCResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw ConfluxRPCResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// The node lists no address's transactions, so none are read
    ///
    /// - Throws: ``ConfluxRPCResponseError/requestFailed(_:)``, always
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw ConfluxRPCResponseError.requestFailed(Self.noTransactions)
    }

    /// No answer of the node holds an address's transactions
    ///
    /// - Throws: ``ConfluxRPCResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw ConfluxRPCResponseError.requestFailed(Self.noTransactions)
    }
}

extension ConfluxRPC {
    /// `cfx_getBalance`'s result, `0x` and hex digits: the balance in CFX's main contract, counted in drip
    static func balance(_ result: String) throws -> Amount<ConfluxContract> {
        guard let quantity = quantity(hex: result) else {
            throw ConfluxRPCResponseError.requestFailed("\(result) is not a count of drip")
        }
        return .init(quantity: quantity, currency: ConfluxChain.default.mainContract)
    }
}
