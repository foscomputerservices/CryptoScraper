// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the Etherscan web service
public struct Etherscan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public typealias Contract = EthereumContract

    public static let supportedERCTokenTypes: Set<ERCTokenType> = Set(ERCTokenType.allCases)
    public static let endPoint: URL = .init(string: "https://api.etherscan.io/api")!
    public static let apiKeyName: String = "ETHER_SCAN_KEY"
    public let userReadableName: String = "Etherscan"

    private static var _apiKey: String?
    public static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey = newValue }
    }

    /// If ``serviceConfigured`` == *true* returns a new instance
    public init?() {
        guard Self.serviceConfigured else { return nil }
    }
}
