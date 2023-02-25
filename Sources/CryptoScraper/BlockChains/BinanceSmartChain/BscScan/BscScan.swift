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

    private static var _apiKey: String?
    public static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey = newValue }
    }

    public init() {}
}
