// VeChainThor.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for a public VeChainThor node's REST API, `mainnet.vechain.org`, keyless
///
/// Reads VET and VTHO: an account's balance and energy (`/accounts/{address}`), and its VET transfers
/// (`/logs/transfer`). Any other token's balance is not read.
public struct VeChainThor: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = VeChainContract

    /// The VeChain Foundation's public mainnet node
    public static let endPoint: URL = .init(string: "https://mainnet.vechain.org")!

    /// "VeChainThor"
    public let userReadableName: String = "VeChainThor"

    public init() {}
}

public enum VeChainThorResponseError: Error {
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
            return "Unable to read a token's balance on VeChain; only VET's and VTHO's are read"
        }
    }
}

extension VeChainThor {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = VeChainContract

        let hash: String
        let fromContract: VeChainContract?
        let toContract: VeChainContract?
        let amount: Amount<VeChainContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<VeChainContract>?
        var gasUsed: Amount<VeChainContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension VeChainThor {
    /// A quantity as the node writes it, `0x` and hex digits; `nil` when it is not one
    static func quantity(hex text: String) -> Int128? {
        guard text.hasPrefix("0x"), text.count > 2 else {
            return nil
        }
        return Int128(text.dropFirst(2), radix: 16)
    }
}
