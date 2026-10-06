// BscScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// A ``CryptoScanner`` implementation for the BscScan web service
public struct BscScan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = BNBContract

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20, .erc721]
    public static let endPoint: URL = .init(string: "https://api.bscscan.com/api")!
    public static let apiKeyName: String = "BSC_SCAN_KEY"
    public let userReadableName: String = "BscScan"

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
