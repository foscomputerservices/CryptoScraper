// BscScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

/// A ``CryptoScanner`` implementation for the BscScan web service
///
/// BNB Smart Chain's configuration of Etherscan's API V2. V2 refuses the chain to a free key ("Free API access is not
/// supported for this chain", recorded 2026-10-07), so with a free key every call V2 answers throws
/// ``EthereumScannerResponseError/requestFailed(_:)`` in V2's words, never a zero.
public struct BscScan: EthereumScanner, Sendable {
    // MARK: EthereumScanner Protocol

    public typealias Contract = BNBContract

    /// The chain V2 is asked for, `EIP155.BinanceSmartChain.chainId`
    public static let chainId: String = EIP155.BinanceSmartChain.chainId

    public static let supportedERCTokenTypes: Set<ERCTokenType> = [.erc20, .erc721]
    public let userReadableName: String = "BscScan"

    /// A new instance, configured or not
    ///
    /// Never `nil`, so a chain always specifies its scanner (the owner's word, 2026-10-07). Until its key is set
    /// (``serviceConfigured``), every call throws `EthereumScannerResponseError.missingApiKey`, never a zero. The key and
    /// the endpoint are Etherscan's API V2's, shared with every chain's configuration (``Etherscan/apiKey``).
    public init() {}
}
