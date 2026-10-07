// Koios.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Koios's public Cardano API, `api.koios.rest`, keyless
///
/// Reads ADA: an address's balance (`address_info`) and its transactions (`address_txs`, then `tx_info` for their
/// inputs and outputs), each the ADA the address gained or lost in it. A native asset's balance is not read.
public struct Koios: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = CardanoContract

    /// Koios's public mainnet API
    public static let endPoint: URL = .init(string: "https://api.koios.rest/api/v1")!

    /// "Koios"
    public let userReadableName: String = "Koios"

    public init() {}
}

public enum KoiosResponseError: Error {
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
            return "Unable to read a native asset's balance on Cardano; only ADA's is read"
        }
    }
}

extension Koios {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = CardanoContract

        let hash: String
        let fromContract: CardanoContract?
        let toContract: CardanoContract?
        let amount: Amount<CardanoContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<CardanoContract>?
        var gasUsed: Amount<CardanoContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension Koios {
    /// One POST of `body` to Koios's `method`
    static func post<Result: Decodable & Sendable>(_ method: String, _ body: [String: Any]) async throws -> Result {
        try await DataFetch<URLSession>.default.send(
            data: JSONSerialization.data(withJSONObject: body), to: endPoint.appending(path: method),
            httpMethod: "POST", headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )
    }
}
