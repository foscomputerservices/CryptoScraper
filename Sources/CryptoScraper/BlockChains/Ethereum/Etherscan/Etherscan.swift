// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// A ``CryptoScanner`` implementation for the Etherscan web service
public struct Etherscan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = EthereumContract

    public static let supportedERCTokenTypes: Set<ERCTokenType> = Set(ERCTokenType.allCases)
    public static let endPoint: URL = .init(string: "https://api.etherscan.io/api")!
    public static let apiKeyName: String = "ETHER_SCAN_KEY"
    public let userReadableName: String = "Etherscan"

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    public static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey.withLock { $0 = newValue } }
    }

    /// If ``serviceConfigured`` == *true* returns a new instance
    public init?() {
        guard Self.serviceConfigured else { return nil }
    }
}
