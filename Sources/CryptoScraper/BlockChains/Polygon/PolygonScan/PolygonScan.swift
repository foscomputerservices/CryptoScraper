// PolygonScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoScanner`` implementation for the PolygonScan web service
public struct PolygonScan: EthereumScanner {
    // MARK: EthereumScanner Protocol

    public static let endPoint: URL = .init(string: "https://api.polygonscan.com/api")!
    public static let apiKeyName: String = "POLYGON_SCAN_KEY"
    public let userReadableName: String = "PolygonScan"

    private static var _apiKey: String?
    public static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey = newValue }
    }

    public init() {}
}
