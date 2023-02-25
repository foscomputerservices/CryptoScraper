// EthereumScanner.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A protocol and standardized implementation of an Ethereum-style scanner
///
/// Most Ethereum-based scanners work in much the same way as they all are
/// forks of the same codebase.  Conforming to this protocol provides an
/// implementation of these standardized services.
public protocol EthereumScanner: CryptoScanner {
    /// The base URL of the scanner
    static var endPoint: URL { get }

    /// The name of the environment variable that stores the API key
    static var apiKeyName: String { get }

    static var apiKey: String? { get set }

    /// A unique, but user-readable name for the scanner (e.g. Etherscan, BscScan, etc.)
    var userReadableName: String { get }

    /// Returns the balance of the given account
    ///
    /// - Parameter account: The ``CryptoContract`` account to query the balance for
    func getBalance(forAccount account: CryptoContract) async throws -> CryptoAmount

    /// Returns balance of the given token for a given account
    ///
    /// - Parameters:
    ///   - contract: The ``CryptoContract`` of the token to query
    ///   - address: The ``CryptoContract`` address that holds the token
    func getBalance(forToken contract: CryptoContract, forAccount account: CryptoContract) async throws -> CryptoAmount

    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The ``CryptoContract`` from which to retrieve the transactions
    func getTransactions(forAccount account: CryptoContract) async throws -> [CryptoTransaction]
}

extension EthereumScanner {
    static func requireApiKey() throws -> String {
        guard let apiKey else { throw EthereumScannerResponseError.missingApiKey(apiKeyName) }

        return apiKey
    }

    static var serviceConfigured: Bool { apiKey != nil }
}

public enum EthereumScannerResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The amount received could not be converted to a ``CryptoAmount``
    case invalidAmount

    /// The  *value* for *field* could not be converted to type *type*
    case invalidData(type: String, field: String, value: String)

    /// The environment variable specifying the Api Key was not set
    case missingApiKey(_ keyName: String)

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let message):
            return message
        case .invalidAmount:
            return "Invalid amount"
        case .invalidData(let type, let field, let value):
            return "Invalid field data '\(value)' for \(type):\(field)"
        case .missingApiKey(let keyName):
            return "An API Key was not provided in the environment \(keyName)"
        }
    }
}
