// BscScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the BscScan web service
public struct BscScan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public static let endPoint: URL = .init(string: "https://api.bscscan.com/api")!
    public static let apiKeyName: String = "BSC_SCAN_KEY"
    public let userReadableName: String = "BscScan"

    public init() {}
}
