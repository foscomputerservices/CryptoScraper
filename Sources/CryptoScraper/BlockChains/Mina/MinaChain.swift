// MinaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Mina, `MINA.Mina.chainId`: its contracts ``MinaContract``, its scanner ``Minascan``
public final class MinaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = MINA.Mina.chainId

    /// "Mina"
    public let userReadableName: String = "Mina"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<MinaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// MINA, the chain's coin, under the placeholder address `mina`
    public let mainContract: MinaContract!

    /// The contract at `address`, validated as `B62` and 52 more characters of base58, or the coin's placeholder; kept
    /// as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> MinaContract {
        let contract = MinaContract(address: address)
        guard contract == mainContract || MinaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: MinaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<MinaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<MinaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Minascan's public node GraphQL, `api.minascan.io`
    public let scanner: Minascan = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<MinaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let minaContractAddress = "mina"

    /// The one Mina chain
    public static let `default`: MinaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.minaContractAddress)
    }
}

public extension CryptoChain where Self == MinaChain {
    /// The one Mina chain
    static var mina: MinaChain { .default }
}
