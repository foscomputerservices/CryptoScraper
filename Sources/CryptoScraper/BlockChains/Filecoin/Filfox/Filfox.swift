// Filfox.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Filfox's public API, `filfox.info/api/v1`, keyless
///
/// Reads FIL: an address's balance (`/address/{address}`) and its messages (`/address/{address}/messages`). A
/// token's balance is not read.
public struct Filfox: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = FilecoinContract

    /// Filfox's public mainnet API
    public static let endPoint: URL = .init(string: "https://filfox.info/api/v1")!

    /// "Filfox"
    public let userReadableName: String = "Filfox"

    public init() {}
}

public enum FilfoxResponseError: Error {
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
            return "Unable to read a token's balance on Filecoin; only FIL's is read"
        }
    }
}

extension Filfox {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = FilecoinContract

        let hash: String
        let fromContract: FilecoinContract?
        let toContract: FilecoinContract?
        let amount: Amount<FilecoinContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<FilecoinContract>?
        var gasUsed: Amount<FilecoinContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
