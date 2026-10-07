// Blockchair.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Blockchair's public API, `api.blockchair.com`, keyless and rate-limited,
/// configured per chain by Blockchair's slug for it
///
/// Reads the chain's coin: an address's balance and its latest transactions, each the balance change Blockchair's
/// address dashboard states (`/<slug>/dashboards/address/<address>?transaction_details=true`). A token's balance is
/// not read.
///
/// ```swift
/// public let scanner: Blockchair<LitecoinContract> = .init(slug: "litecoin")
/// ```
public struct Blockchair<Contract: CryptoContract>: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    /// Blockchair's public API
    public static var endPoint: URL { URL(string: "https://api.blockchair.com")! }

    /// "Blockchair"
    public let userReadableName: String = "Blockchair"

    /// Blockchair's name for the chain, the first part of every path it serves: `litecoin`, `bitcoin-cash`
    public let slug: String

    /// The address as Blockchair is asked for it: the contract's own, unless the chain states another form
    let apiAddress: @Sendable (Contract) -> String

    /// Initializes the scanner for the chain Blockchair calls `slug`
    ///
    /// - Parameter slug: Blockchair's name for the chain
    public init(slug: String) {
        self.init(slug: slug, apiAddress: { $0.address })
    }

    /// Initializes the scanner for the chain Blockchair calls `slug`, asking for an address in the form `apiAddress`
    /// writes it (a CashAddr's prefix put back)
    init(slug: String, apiAddress: @escaping @Sendable (Contract) -> String) {
        self.slug = slug
        self.apiAddress = apiAddress
    }
}

public enum BlockchairResponseError: Error {
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
            return "Unable to read a token's balance through Blockchair; only the chain's coin is read"
        }
    }
}

extension Blockchair {
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
        var gasPrice: Amount<Contract>? { nil }
        var gasUsed: Amount<Contract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        var type: String? { nil }
    }
}
