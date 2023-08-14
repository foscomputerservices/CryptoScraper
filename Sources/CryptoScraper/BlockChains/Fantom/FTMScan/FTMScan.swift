// FTMScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the FMTScan web service
public struct FTMScan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public typealias Contract = FantomContract

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20]
    public static let endPoint: URL = .init(string: "https://api.ftmscan.com/api")!
    public static let apiKeyName: String = "FTM_SCAN_KEY"
    public let userReadableName: String = "FTMScan"

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
