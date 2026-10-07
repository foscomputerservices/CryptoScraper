// NilScanner.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A scanner for a chain that has none: zero balances and no transactions, as ``ZeroAmountScanner`` answers
///
/// A chain always specifies its scanner, never `nil`; a chain with nothing to scan specifies this one. Generic over
/// the contract, where ``ZeroAmountScanner`` is bound to ``ZeroAmountContract``.
///
/// ```swift
/// public let scanner: NilScanner<QtumContract> = .init()
/// try await scanner.getBalance(forAccount: account).quantity      // 0
/// ```
public struct NilScanner<Contract: CryptoContract>: CryptoScanner, Sendable {
    /// "No scanner"
    public var userReadableName: String { "No scanner" }

    public init() {}

    /// Zero, in the chain's main contract
    public func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        .zero
    }

    /// Zero, in the chain's main contract
    public func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        .zero
    }

    /// No transactions
    public func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        []
    }

    /// No transactions
    public func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        []
    }
}
