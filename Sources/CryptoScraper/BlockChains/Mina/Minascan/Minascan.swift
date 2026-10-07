// Minascan.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Minascan's public Mina node, its GraphQL, `api.minascan.io`, keyless
///
/// Reads MINA: an account's balance (`account(publicKey:)`). The node lists no account's transactions, so
/// ``getTransactions(forAccount:)`` throws; a token's balance is not read.
public struct Minascan: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = MinaContract

    /// Minascan's public mainnet node's GraphQL
    public static let endPoint: URL = .init(string: "https://api.minascan.io/node/mainnet/v1/graphql")!

    /// "Minascan"
    public let userReadableName: String = "Minascan"

    public init() {}
}

public enum MinascanResponseError: Error {
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
            return "Unable to read a token's balance on Mina; only MINA's is read"
        }
    }
}

extension Minascan {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = MinaContract

        let hash: String
        let fromContract: MinaContract?
        let toContract: MinaContract?
        let amount: Amount<MinaContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<MinaContract>?
        var gasUsed: Amount<MinaContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
