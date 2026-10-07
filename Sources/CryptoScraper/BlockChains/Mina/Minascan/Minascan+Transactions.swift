// Minascan+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Minascan {
    /// The node lists no account's transactions, so none are read
    ///
    /// - Throws: ``MinascanResponseError/requestFailed(_:)``, always: a Mina node holds the ledger's balances, not an
    ///   account's history
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw MinascanResponseError.requestFailed(Self.noTransactions)
    }

    /// The node lists no account's transactions, so no answer of it holds any
    ///
    /// - Throws: ``MinascanResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw MinascanResponseError.requestFailed(Self.noTransactions)
    }
}

extension Minascan {
    static let noTransactions = "a Mina node's GraphQL lists no account's transactions"
}
