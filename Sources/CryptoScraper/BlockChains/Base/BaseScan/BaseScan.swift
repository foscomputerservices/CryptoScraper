// BaseScan.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

/// A ``CryptoScanner`` implementation for Base's explorer, BaseScan: Base's configuration of Etherscan's
/// API V2, named after the explorer V2's chain list names for the chain
public struct BaseScan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = BaseContract

    /// The chain V2 is asked for, `EIP155.Base.chainId`
    public static let chainId: String = EIP155.Base.chainId

    /// ERC-20 tokens
    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20]
    /// "BaseScan"
    public let userReadableName: String = "BaseScan"

    /// A new instance, configured or not
    ///
    /// Never `nil`, so a chain always specifies its scanner (the owner's word, 2026-10-07). Until its key is set
    /// (``serviceConfigured``), every call throws `EthereumScannerResponseError.missingApiKey`, never a zero. The key and
    /// the endpoint are Etherscan's API V2's, shared with every chain's configuration (``Etherscan/apiKey``). A key whose
    /// plan does not cover the chain is refused in V2's words, thrown as `requestFailed`.
    public init() {}
}
