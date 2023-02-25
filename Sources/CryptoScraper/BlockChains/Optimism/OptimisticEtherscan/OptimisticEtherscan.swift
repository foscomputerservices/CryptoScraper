// OptimisticEtherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the OptimismEtherscan web service
public struct OptimisticEtherscan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public static let endPoint: URL = .init(string: "https://api-optimistic.etherscan.io/api")!
    public static let apiKeyName: String = "OPTIMISTIC_ETHER_SCAN_KEY"
    public let userReadableName: String = "OptimisticEtherscan"

    private static var _apiKey: String?
    public static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey = newValue }
    }

    public init() {}
}
