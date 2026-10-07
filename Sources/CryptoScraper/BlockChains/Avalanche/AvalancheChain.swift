// AvalancheChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Avalanche C-Chain, `EIP155.Avalanche.chainId`: an EVM chain, its contracts ``AvalancheContract``, on Optimism's pattern
public final class AvalancheChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Avalanche.chainId

    /// "Avalanche C-Chain"
    public let userReadableName: String = "Avalanche C-Chain"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<AvalancheContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// AVAX, the chain's coin, under the placeholder address `avax`
    public let mainContract: AvalancheContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> AvalancheContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: AvalancheContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<AvalancheContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<AvalancheContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Etherscan's API V2 configured for `EIP155.Avalanche.chainId`
    public let scanner: SnowScan = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<AvalancheContract>? {
        tokens.withLock { $0?[address] }
    }

    static let avaxContractAddress = "avax"

    /// The one Avalanche C-Chain chain
    public static let `default`: AvalancheChain = .init()

    private init() {
        self.mainContract = .init(address: Self.avaxContractAddress)
    }
}

public extension CryptoChain where Self == AvalancheChain {
    /// The one Avalanche C-Chain chain
    static var avalanche: AvalancheChain { .default }
}
