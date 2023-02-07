// BscScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct BscScan: CryptoScanner {
    static let endPoint: URL = .init(string: "https://api.bscscan.com/api")!

    static var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["BSC_SCAN_KEY"] else {
            fatalError("BSC_SCAN_KEY is not set in the environment")
        }

        return key
    }

    public let userReadableName: String = "Bsc Scan"

    public init() {}
}

public enum BscScanResponseError: Error {
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
