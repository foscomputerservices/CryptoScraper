// HederaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Hedera, `HEDERA.Hedera.chainId`: its contracts ``HederaContract``, its scanner ``HederaMirrorNode``
public final class HederaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = HEDERA.Hedera.chainId

    /// "Hedera"
    public let userReadableName: String = "Hedera"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<HederaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// HBAR, the chain's coin, under the placeholder address `hbar`
    public let mainContract: HederaContract!

    /// The contract at `address`, validated as an entity id, `<shard>.<realm>.<num>` in decimal, or the coin's
    /// placeholder; normalized to its numbers without leading zeros, since the entity id is three integers
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> HederaContract {
        let contract = HederaContract(address: address)
        guard contract == mainContract || HederaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: HederaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<HederaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<HederaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Hedera's public mirror node, `mainnet-public.mirrornode.hedera.com`
    public let scanner: HederaMirrorNode = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<HederaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let hbarContractAddress = "hbar"

    /// The one Hedera chain
    public static let `default`: HederaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.hbarContractAddress)
    }
}

public extension CryptoChain where Self == HederaChain {
    /// The one Hedera chain
    static var hedera: HederaChain { .default }
}
