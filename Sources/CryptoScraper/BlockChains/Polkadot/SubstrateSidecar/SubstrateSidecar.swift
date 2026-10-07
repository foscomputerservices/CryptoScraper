// SubstrateSidecar.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Parity's public Substrate API Sidecar, the REST service over a
/// Polkadot-family relay chain's node, keyless, configured per chain by the sidecar's address
///
/// Reads the chain's coin: an account's free balance (`/accounts/{address}/balance-info`). The sidecar lists no
/// account's transactions, so ``getTransactions(forAccount:)`` throws; a token's balance is not read.
///
/// ```swift
/// public let scanner: SubstrateSidecar<PolkadotContract> = .init(
///     endPoint: URL(string: "https://polkadot-public-sidecar.parity-chains.parity.io")!
/// )
/// ```
public struct SubstrateSidecar<Contract: CryptoContract>: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    /// The chain's public sidecar, the first part of every path it serves
    public let endPoint: URL

    /// "Substrate API Sidecar"
    public let userReadableName: String = "Substrate API Sidecar"

    /// Initializes the scanner for the chain whose sidecar is at `endPoint`
    ///
    /// - Parameter endPoint: The chain's public sidecar
    public init(endPoint: URL) {
        self.endPoint = endPoint
    }
}

public enum SubstrateSidecarResponseError: Error {
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
            return "Unable to read a token's balance through the Substrate API Sidecar; only the chain's coin is read"
        }
    }
}
