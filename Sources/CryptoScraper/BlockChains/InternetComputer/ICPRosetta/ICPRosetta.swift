// ICPRosetta.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A ``CryptoScanner`` implementation for the Internet Computer's public Rosetta API,
/// `rosetta-api.internetcomputer.org`, keyless
///
/// Reads ICP: an account identifier's balance (`/account/balance`) and its transactions (`/search/transactions`),
/// each the ICP the account gained or lost in it. A token's balance is not read.
public struct ICPRosetta: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = InternetComputerContract

    /// The Internet Computer's public Rosetta API
    public static let endPoint: URL = .init(string: "https://rosetta-api.internetcomputer.org")!

    /// "ICP Rosetta"
    public let userReadableName: String = "ICP Rosetta"

    public init() {}
}

public enum ICPRosettaResponseError: Error {
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
            return "Unable to read a token's balance on the Internet Computer; only ICP's is read"
        }
    }
}

extension ICPRosetta {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = InternetComputerContract

        let hash: String
        let fromContract: InternetComputerContract?
        let toContract: InternetComputerContract?
        let amount: Amount<InternetComputerContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<InternetComputerContract>?
        var gasUsed: Amount<InternetComputerContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

extension ICPRosetta {
    /// The ICP ledger's network as Rosetta names it: the ledger canister's principal, in hex
    static let networkIdentifier: [String: String] = [
        "blockchain": "Internet Computer", "network": "00000000000000020101"
    ]

    /// One POST of `body`, with the network named, to Rosetta's `path`
    static func post<Result: Decodable & Sendable>(_ path: String, _ body: [String: Any]) async throws -> Result {
        var body = body
        body["network_identifier"] = networkIdentifier
        return try await DataFetch<URLSession>.default.send(
            data: JSONSerialization.data(withJSONObject: body), to: endPoint.appending(path: path),
            httpMethod: "POST", headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )
    }

    /// An amount as Rosetta writes it: `{ "value": "<e8s>", "currency": { "symbol": "ICP", "decimals": 8 } }`
    struct RosettaAmount: Decodable, Sendable {
        let value: String
        let currency: Currency

        struct Currency: Decodable, Sendable {
            let symbol: String
            let decimals: Int
        }

        /// The count of e8s, signed; thrown when the currency is not ICP at 8
        func e8s() throws -> Int128 {
            guard currency.symbol == "ICP", currency.decimals == 8, let quantity = Int128(value) else {
                throw ICPRosettaResponseError.requestFailed("\(value) \(currency.symbol) is not a count of e8s")
            }
            return quantity
        }
    }
}
