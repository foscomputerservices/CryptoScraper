// CardanoChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Cardano, `CIP34.Cardano.chainId`: its contracts ``CardanoContract``, its scanner ``Koios``
public final class CardanoChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = CIP34.Cardano.chainId

    /// "Cardano"
    public let userReadableName: String = "Cardano"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<CardanoContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ADA, the chain's coin, under the placeholder address `ada`
    public let mainContract: CardanoContract!

    /// The contract at `address`, validated as a Shelley address, bech32 `addr1` in lower case; a Byron address, base58
    /// beginning `Ae2` or `DdzFF`; or a native asset, its policy id (56 lower-case hex digits) and its name (up to 64
    /// more, whole bytes, so an even count), or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> CardanoContract {
        let contract = CardanoContract(address: address)
        guard contract == mainContract || CardanoContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: CardanoContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<CardanoContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<CardanoContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Koios's public API, `api.koios.rest`, keyless
    public let scanner: Koios = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<CardanoContract>? {
        tokens.withLock { $0?[address] }
    }

    static let adaContractAddress = "ada"

    /// The one Cardano chain
    public static let `default`: CardanoChain = .init()

    private init() {
        self.mainContract = .init(address: Self.adaContractAddress)
    }
}

public extension CryptoChain where Self == CardanoChain {
    /// The one Cardano chain
    static var cardano: CardanoChain { .default }
}
