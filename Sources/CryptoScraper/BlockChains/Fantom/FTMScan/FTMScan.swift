// FTMScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// A ``CryptoScanner`` implementation for the FMTScan web service
public struct FTMScan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = FantomContract

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20]
    public static let endPoint: URL = .init(string: "https://api.ftmscan.com/api")!
    public static let apiKeyName: String = "FTM_SCAN_KEY"
    public let userReadableName: String = "FTMScan"

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
