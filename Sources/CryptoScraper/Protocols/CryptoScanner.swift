// CryptoScanner.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A generalized protocol for retrieving standardized information across block chains
public protocol CryptoScanner {
    associatedtype Contract: CryptoContract

    /// A user-readable name for the scanner
    var userReadableName: String { get }

    /// Returns the balance of the given account
    ///
    /// - Parameter account: The ``CryptoContract`` account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> CryptoAmount

    /// Returns balance of the given token for a given account
    ///
    /// - Parameters:
    ///   - contract: The ``CryptoContract`` of the token to query
    ///   - address: The ``CryptoContract`` address that holds the token
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> CryptoAmount

    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The ``CryptoContract`` from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [CryptoTransaction]
}
