// ArweaveGateway.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for the public Arweave gateway, `arweave.net`, keyless
///
/// Reads AR: a wallet's balance (`/wallet/{address}/balance`) and the transactions it sent and received (the
/// gateway's GraphQL, `/graphql`). A token's balance is not read.
public struct ArweaveGateway: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = ArweaveContract

    /// The public Arweave gateway
    public static let endPoint: URL = .init(string: "https://arweave.net")!

    /// "Arweave Gateway"
    public let userReadableName: String = "Arweave Gateway"

    public init() {}
}

public enum ArweaveGatewayResponseError: Error {
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
            return "Unable to read a token's balance on Arweave; only AR's is read"
        }
    }
}

extension ArweaveGateway {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = ArweaveContract

        let hash: String
        let fromContract: ArweaveContract?
        let toContract: ArweaveContract?
        let amount: Amount<ArweaveContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<ArweaveContract>?
        var gasUsed: Amount<ArweaveContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
