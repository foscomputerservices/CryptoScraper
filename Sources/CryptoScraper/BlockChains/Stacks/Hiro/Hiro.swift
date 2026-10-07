// Hiro.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Hiro's public Stacks API, `api.hiro.so`, keyless
///
/// Reads STX: an address's balance (`/address/{principal}/balances`) and its transactions
/// (`/address/{principal}/transactions`). A token's balance is not read.
public struct Hiro: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = StacksContract

    /// Hiro's public mainnet Stacks API
    public static let endPoint: URL = .init(string: "https://api.hiro.so/extended/v1")!

    /// "Hiro"
    public let userReadableName: String = "Hiro"

    public init() {}
}

public enum HiroResponseError: Error {
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
            return "Unable to read a token's balance on Stacks; only STX's is read"
        }
    }
}

extension Hiro {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = StacksContract

        let hash: String
        let fromContract: StacksContract?
        let toContract: StacksContract?
        let amount: Amount<StacksContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<StacksContract>?
        var gasUsed: Amount<StacksContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
