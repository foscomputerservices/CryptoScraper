// FlowAccessAPI.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Flow's public Access API over REST, `rest-mainnet.onflow.org`, keyless
///
/// Reads FLOW: an account's balance (`/v1/accounts/{address}`). The Access API lists no account's transactions,
/// so ``getTransactions(forAccount:)`` throws; a token's balance is not read.
public struct FlowAccessAPI: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = FlowContract

    /// Flow's public mainnet Access API
    public static let endPoint: URL = .init(string: "https://rest-mainnet.onflow.org/v1")!

    /// "Flow Access API"
    public let userReadableName: String = "Flow Access API"

    public init() {}
}

public enum FlowAccessAPIResponseError: Error {
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
            return "Unable to read a token's balance on Flow; only FLOW's is read"
        }
    }
}

extension FlowAccessAPI {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = FlowContract

        let hash: String
        let fromContract: FlowContract?
        let toContract: FlowContract?
        let amount: Amount<FlowContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<FlowContract>?
        var gasUsed: Amount<FlowContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
