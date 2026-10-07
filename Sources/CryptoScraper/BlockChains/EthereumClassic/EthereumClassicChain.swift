// EthereumClassicChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Ethereum Classic, `EIP155.EthereumClassic.chainId`: an EVM chain, its contracts ``EthereumClassicContract``, on Optimism's pattern
public final class EthereumClassicChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.EthereumClassic.chainId

    /// "Ethereum Classic"
    public let userReadableName: String = "Ethereum Classic"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<EthereumClassicContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ETC, the chain's coin, under the placeholder address `etc`
    public let mainContract: EthereumClassicContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> EthereumClassicContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: EthereumClassicContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<EthereumClassicContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<EthereumClassicContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Etherscan's API V2 does not serve `EIP155.EthereumClassic.chainId` (its chain list of
    /// 2026-10-07); zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<EthereumClassicContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<EthereumClassicContract>? {
        tokens.withLock { $0?[address] }
    }

    static let etcContractAddress = "etc"

    /// The one Ethereum Classic chain
    public static let `default`: EthereumClassicChain = .init()

    private init() {
        self.mainContract = .init(address: Self.etcContractAddress)
    }
}

public extension CryptoChain where Self == EthereumClassicChain {
    /// The one Ethereum Classic chain
    static var ethereumClassic: EthereumClassicChain { .default }
}
