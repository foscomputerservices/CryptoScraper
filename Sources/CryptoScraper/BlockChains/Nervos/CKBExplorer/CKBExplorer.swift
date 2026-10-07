// CKBExplorer.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Nervos's public CKB Explorer API, `mainnet-api.explorer.nervos.org`,
/// keyless, which answers in JSON:API (`application/vnd.api+json`)
///
/// Reads CKB: an address's balance (`/api/v1/addresses/{address}`) and its transactions
/// (`/api/v1/address_transactions/{address}`), each the address's income in it. A token's balance is not read.
public struct CKBExplorer: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = NervosContract

    /// The CKB Explorer's public mainnet API
    public static let endPoint: URL = .init(string: "https://mainnet-api.explorer.nervos.org/api/v1")!

    /// "CKB Explorer"
    public let userReadableName: String = "CKB Explorer"

    public init() {}
}

public enum CKBExplorerResponseError: Error {
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
            return "Unable to read a token's balance on Nervos; only CKB's is read"
        }
    }
}

extension CKBExplorer {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = NervosContract

        let hash: String
        let fromContract: NervosContract?
        let toContract: NervosContract?
        let amount: Amount<NervosContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<NervosContract>?
        var gasUsed: Amount<NervosContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension CKBExplorer {
    /// The JSON:API media type the explorer asks for and answers in
    static let mediaType = "application/vnd.api+json"

    /// One GET of `url`, asking in the explorer's media type, which is not plain JSON's
    static func get<Result: Decodable & Sendable>(_ url: URL) async throws -> Result {
        try await DataFetch<URLSession>.default.send(
            to: url, httpMethod: "GET",
            headers: [(field: "Accept", value: mediaType), (field: "Content-Type", value: mediaType)],
            locale: nil, checkReceivedMimeType: false
        )
    }
}
