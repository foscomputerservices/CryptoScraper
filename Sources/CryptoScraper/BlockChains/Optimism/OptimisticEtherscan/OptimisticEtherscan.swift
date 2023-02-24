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

    public init() {}
}
