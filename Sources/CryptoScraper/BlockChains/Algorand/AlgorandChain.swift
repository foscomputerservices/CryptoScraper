// AlgorandChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Algorand, `ALGORAND.Algorand.chainId`: its contracts ``AlgorandContract``, its scanner ``AlgoNode``
public final class AlgorandChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = ALGORAND.Algorand.chainId

    /// "Algorand"
    public let userReadableName: String = "Algorand"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<AlgorandContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ALGO, the chain's coin, under the placeholder address `algo`
    public let mainContract: AlgorandContract!

    /// The contract at `address`, validated as an account (58 characters of upper-case base32) or an asset's numeric
    /// id, or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> AlgorandContract {
        let contract = AlgorandContract(address: address)
        guard contract == mainContract || AlgorandContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: AlgorandContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<AlgorandContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<AlgorandContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: AlgoNode's public node and indexer, `mainnet-api.algonode.cloud` and
    /// `mainnet-idx.algonode.cloud`
    public let scanner: AlgoNode = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<AlgorandContract>? {
        tokens.withLock { $0?[address] }
    }

    static let algoContractAddress = "algo"

    /// The one Algorand chain
    public static let `default`: AlgorandChain = .init()

    private init() {
        self.mainContract = .init(address: Self.algoContractAddress)
    }
}

public extension CryptoChain where Self == AlgorandChain {
    /// The one Algorand chain
    static var algorand: AlgorandChain { .default }
}
