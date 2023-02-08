// FTMScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the FMTScan web service
public struct FTMScan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public static let endPoint: URL = .init(string: "https://api.ftmscan.com/api")!
    public static let apiKeyName: String = "FTM_SCAN_KEY"
    public let userReadableName: String = "FTMScan"

    public init() {}
}
