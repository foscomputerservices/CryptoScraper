// FTMScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

/// A ``CryptoScanner`` implementation for the FTMScan web service
///
/// Fantom's configuration of Etherscan's API V2. V2 does not serve Fantom's chain, `eip155:250` (its chain list of
/// 2026-10-07, recorded), so every call V2 answers throws ``EthereumScannerResponseError/requestFailed(_:)`` with V2's
/// "Missing or unsupported chainid parameter", never a zero.
public struct FTMScan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = FantomContract

    /// The chain V2 is asked for, `EIP155.Fantom.chainId`
    public static let chainId: String = EIP155.Fantom.chainId

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20]
    public let userReadableName: String = "FTMScan"

    /// A new instance, configured or not
    ///
    /// Never `nil`, so a chain always specifies its scanner (the owner's word, 2026-10-07). Until its key is set
    /// (``serviceConfigured``), every call throws `EthereumScannerResponseError.missingApiKey`, never a zero. The key and
    /// the endpoint are Etherscan's API V2's, shared with every chain's configuration (``Etherscan/apiKey``).
    public init() {}
}
