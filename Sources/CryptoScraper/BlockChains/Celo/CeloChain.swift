// CeloChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Celo, `EIP155.Celo.chainId`: an EVM chain, its contracts ``CeloContract``, on Optimism's pattern
public final class CeloChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Celo.chainId

    /// "Celo"
    public let userReadableName: String = "Celo"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<CeloContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// CELO, the chain's coin, under the placeholder address `celo`
    public let mainContract: CeloContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> CeloContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: CeloContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<CeloContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<CeloContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Etherscan's API V2 configured for `EIP155.Celo.chainId`
    public let scanner: CeloScan = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<CeloContract>? {
        tokens.withLock { $0?[address] }
    }

    static let celoContractAddress = "celo"

    /// The one Celo chain
    public static let `default`: CeloChain = .init()

    private init() {
        self.mainContract = .init(address: Self.celoContractAddress)
    }
}

public extension CryptoChain where Self == CeloChain {
    /// The one Celo chain
    static var celo: CeloChain { .default }
}
