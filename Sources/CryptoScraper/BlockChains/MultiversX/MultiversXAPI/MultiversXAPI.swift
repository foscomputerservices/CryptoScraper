// MultiversXAPI.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for MultiversX's public API, `api.multiversx.com`, keyless
///
/// Reads EGLD: an account's balance (`/accounts/{address}`) and its transactions
/// (`/accounts/{address}/transactions`). A token's balance is not read.
public struct MultiversXAPI: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = MultiversXContract

    /// MultiversX's public mainnet API
    public static let endPoint: URL = .init(string: "https://api.multiversx.com")!

    /// "MultiversX API"
    public let userReadableName: String = "MultiversX API"

    public init() {}
}

public enum MultiversXAPIResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a token's balance on MultiversX; only EGLD's is read"
        }
    }
}

extension MultiversXAPI {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = MultiversXContract

        let hash: String
        let fromContract: MultiversXContract?
        let toContract: MultiversXContract?
        let amount: Amount<MultiversXContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<MultiversXContract>?
        var gasUsed: Amount<MultiversXContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
