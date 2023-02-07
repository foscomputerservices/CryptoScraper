// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct Etherscan: CryptoScanner {
    static let endPiont: URL = .init(string: "https://api.etherscan.io/api")!

    static var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["ETHER_SCAN_KEY"] else {
            fatalError("ETHER_SCAN_KEY is not set in the environment")
        }

        return key
    }

    public init() {}
}

public enum EtherscanResponseError: Error {
    case requestFailed(_ error: String)
    case invalidAmount
    case invalidData(type: String, field: String, value: String)

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let message):
            return message
        case .invalidAmount:
            return "Invalid amount"
        case .invalidData(let type, let field, let value):
            return "Invalid field data '\(value)' for \(type):\(field)"
        }
    }
}
