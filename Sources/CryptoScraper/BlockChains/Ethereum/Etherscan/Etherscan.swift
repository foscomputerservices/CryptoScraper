// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// A ``CryptoScanner`` implementation for the Etherscan web service: Ethereum's configuration of Etherscan's API V2,
/// and the holder of V2's one endpoint and one key, which every ``EthereumScanner`` asks with
///
/// ```swift
/// Etherscan.apiKey = key                     // once, for every EthereumScanner's chain
/// BscScan.apiKey == Etherscan.apiKey         // true
/// ```
public struct Etherscan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = EthereumContract

    /// The chain V2 is asked for, `EIP155.Ethereum.chainId`
    public static let chainId: String = EIP155.Ethereum.chainId

    public static let supportedERCTokenTypes: Set<ERCTokenType> = Set(ERCTokenType.allCases)
    /// Etherscan's API V2: one endpoint for every chain it serves, the chain named by `chainid`
    public static let endPoint: URL = .init(string: "https://api.etherscan.io/v2/api")!
    /// The environment variable holding V2's one key
    public static let apiKeyName: String = "ETHER_SCAN_KEY"
    public let userReadableName: String = "Etherscan"

    // V2's one key, for every chain's configuration. Set from any concurrency domain and read from any, so it is held
    // behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    public static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment[apiKeyName] }
        set { _apiKey.withLock { $0 = newValue } }
    }

    /// A new instance, configured or not
    ///
    /// Never `nil`, so a chain always specifies its scanner (the owner's word, 2026-10-07). Until its key is set
    /// (``serviceConfigured``), every call throws `EthereumScannerResponseError.missingApiKey`, never a zero.
    public init() {}
}
