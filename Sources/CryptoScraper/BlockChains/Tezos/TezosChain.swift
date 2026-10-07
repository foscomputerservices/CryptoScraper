// TezosChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Tezos, `TEZOS.Tezos.chainId`: its contracts ``TezosContract``, its scanner ``TzKT``
public final class TezosChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = TEZOS.Tezos.chainId

    /// "Tezos"
    public let userReadableName: String = "Tezos"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<TezosContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// XTZ, the chain's coin, under the placeholder address `xtz`
    public let mainContract: TezosContract!

    /// The contract at `address`, validated as `tz1`, `tz2`, `tz3` or `KT1` and 33 more characters of base58, or the
    /// coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> TezosContract {
        let contract = TezosContract(address: address)
        guard contract == mainContract || TezosContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: TezosContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<TezosContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<TezosContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: TzKT's public API, `api.tzkt.io`
    public let scanner: TzKT = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<TezosContract>? {
        tokens.withLock { $0?[address] }
    }

    static let xtzContractAddress = "xtz"

    /// The one Tezos chain
    public static let `default`: TezosChain = .init()

    private init() {
        self.mainContract = .init(address: Self.xtzContractAddress)
    }
}

public extension CryptoChain where Self == TezosChain {
    /// The one Tezos chain
    static var tezos: TezosChain { .default }
}
