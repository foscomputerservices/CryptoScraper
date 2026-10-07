// TzKT.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for TzKT's public Tezos API, `api.tzkt.io`, keyless
///
/// Reads XTZ: an account's balance (`/v1/accounts/{address}`) and its transactions
/// (`/v1/accounts/{address}/operations?type=transaction`). A token's balance is not read.
public struct TzKT: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = TezosContract

    /// TzKT's public mainnet API
    public static let endPoint: URL = .init(string: "https://api.tzkt.io/v1")!

    /// "TzKT"
    public let userReadableName: String = "TzKT"

    public init() {}
}

public enum TzKTResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner, only XTZ's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read a token's balance on Tezos; only XTZ's is read"
        }
    }
}
