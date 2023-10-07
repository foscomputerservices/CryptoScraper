// BitcoinExplorer.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the Bitcoin Explorer web service
public struct BitcoinExplorer: CryptoScanner {
    // MARK: CryptoScanner Protocol

    public typealias Contract = BitcoinContract

    public static let endPoint: URL = .init(string: "https://bitcoinexplorer.org/api")!
    public let userReadableName: String = "BitcoinExplorer"

    public init() {}
}

public enum BitcoinExplorerResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// The bitcoin blockchain only has a single token
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown. Address can be base58 or xpub."
        case .unknownToken:
            return "Unable to make requests for non-BTC tokens on this block chain"
        }
    }
}