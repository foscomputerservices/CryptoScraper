// TronScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the TronScan web service
public struct TronScan: CryptoScanner {
    // MARK: EthereumScanner Protocol

    public typealias Contract = TronContract

    public static let endPoint: URL = .init(string: "https://apilist.tronscan.org/api")!
    public let userReadableName: String = "TronScan"

    public init() {}
}

public enum TronScanResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        }
    }
}
