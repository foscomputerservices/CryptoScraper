// HederaMirrorNode.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for Hedera's public mirror node, `mainnet-public.mirrornode.hedera.com`,
/// keyless
///
/// Reads HBAR: an account's balance (`/api/v1/accounts/{id}`) and its transactions
/// (`/api/v1/transactions?account.id={id}`). A token's balance is not read.
public struct HederaMirrorNode: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = HederaContract

    /// Hedera's public mainnet mirror node
    public static let endPoint: URL = .init(string: "https://mainnet-public.mirrornode.hedera.com/api/v1")!

    /// "Hedera Mirror Node"
    public let userReadableName: String = "Hedera Mirror Node"

    public init() {}
}

public enum HederaMirrorNodeResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner, only HBAR's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a token's balance on Hedera; only HBAR's is read"
        }
    }
}

extension HederaMirrorNode {
    /// The mirror node's refusal: `{ "_status": { "messages": [{ "message": … }] } }`
    struct Refusal: Error, Decodable, Sendable {
        let status: Status

        struct Status: Decodable, Sendable {
            let messages: [Message]
        }

        struct Message: Decodable, Sendable {
            let message: String
        }

        private enum CodingKeys: String, CodingKey {
            case status = "_status"
        }

        var mirrorNodeError: HederaMirrorNodeResponseError {
            .requestFailed(status.messages.map(\.message).joined(separator: "; "))
        }
    }

    /// A GET of `url`, its answer as `Result`, a refusal thrown in the mirror node's words
    static func get<Result: Decodable & Sendable>(_ url: URL) async throws -> Result {
        do {
            return try await url.fetch(errorType: Refusal.self)
        } catch let refusal as Refusal {
            throw refusal.mirrorNodeError
        }
    }
}
