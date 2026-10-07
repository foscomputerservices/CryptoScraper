// OptimisticEtherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

/// A ``CryptoScanner`` implementation for the Optimistic Etherscan web service
///
/// Optimistic Etherscan's own API is no longer asked: the scanner is Optimism's configuration of Etherscan's API V2,
/// asked at ``Etherscan/endPoint`` with ``Etherscan/apiKey`` for ``chainId`` (``EthereumScanner``).
public struct OptimisticEtherscan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = OptimismContract

    /// The chain V2 is asked for, `EIP155.Optimism.chainId`
    public static let chainId: String = EIP155.Optimism.chainId

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20]
    public let userReadableName: String = "OptimisticEtherscan"

    /// A new instance, configured or not
    ///
    /// Never `nil`, so a chain always specifies its scanner (the owner's word, 2026-10-07). Until its key is set
    /// (``serviceConfigured``), every call throws `EthereumScannerResponseError.missingApiKey`, never a zero. The key and
    /// the endpoint are Etherscan's API V2's, shared with every chain's configuration (``Etherscan/apiKey``).
    public init() {}
}
