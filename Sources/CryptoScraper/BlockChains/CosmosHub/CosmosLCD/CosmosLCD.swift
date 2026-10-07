// CosmosLCD.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for a Cosmos SDK chain's public LCD, its REST API, keyless, configured per chain
/// by the LCD's address and the denom of the chain's coin
///
/// Reads the chain's coin: an address's balance in that denom (`/cosmos/bank/v1beta1/balances/{address}`) and the
/// latest transactions that paid the address (`/cosmos/tx/v1beta1/txs`, `transfer.recipient`), each the coin the
/// address's balance changed by. A token's balance is not read.
///
/// ```swift
/// public let scanner: CosmosLCD<CosmosHubContract> = .init(
///     endPoint: URL(string: "https://rest.cosmos.directory/cosmoshub")!, denom: "uatom"
/// )
/// ```
public struct CosmosLCD<Contract: CryptoContract>: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    /// The chain's LCD, the first part of every path it serves
    public let endPoint: URL

    /// "Cosmos LCD"
    public let userReadableName: String = "Cosmos LCD"

    /// The denom of the chain's coin, its base unit: `uatom`, `rune`, `uluna`, `afet`
    public let denom: String

    /// Initializes the scanner for the chain whose LCD is at `endPoint`, reading its coin as `denom`
    ///
    /// - Parameters:
    ///   - endPoint: The chain's LCD
    ///   - denom: The denom of the chain's coin
    public init(endPoint: URL, denom: String) {
        self.endPoint = endPoint
        self.denom = denom
    }
}

public enum CosmosLCDResponseError: Error {
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
            return "Unable to read a token's balance through a Cosmos LCD; only the chain's coin is read"
        }
    }
}

extension CosmosLCD {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        let hash: String
        let fromContract: Contract?
        let toContract: Contract?
        let amount: Amount<Contract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<Contract>?
        var gasUsed: Amount<Contract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
