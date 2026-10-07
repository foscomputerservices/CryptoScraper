// BaseChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Base, `EIP155.Base.chainId`: an EVM chain, its contracts ``BaseContract``, on Optimism's pattern
public final class BaseChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Base.chainId

    /// "Base"
    public let userReadableName: String = "Base"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<BaseContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// Ether on Base, the chain's coin, an instance of Ethereum's ether, under the placeholder address `eth`
    public let mainContract: BaseContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> BaseContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: BaseContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<BaseContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<BaseContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Etherscan's API V2 configured for `EIP155.Base.chainId`
    public let scanner: BaseScan = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<BaseContract>? {
        tokens.withLock { $0?[address] }
    }

    static let ethContractAddress = "eth"

    /// The one Base chain
    public static let `default`: BaseChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ethContractAddress)
    }
}

public extension CryptoChain where Self == BaseChain {
    /// The one Base chain
    static var base: BaseChain { .default }
}
