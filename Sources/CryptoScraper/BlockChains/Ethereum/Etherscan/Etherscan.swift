// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the Etherscan web service
public struct Etherscan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public static let endPoint: URL = .init(string: "https://api.etherscan.io/api")!
    public static let apiKeyName: String = "ETHER_SCAN_KEY"
    public let userReadableName: String = "Etherscan"

    private static var _apiKey: String?
    public static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey = newValue }
    }

    public init() {}
}
