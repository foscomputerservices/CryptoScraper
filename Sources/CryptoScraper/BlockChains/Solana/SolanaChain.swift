// SolanaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Solana, `SOLANA.Solana.chainId`: its contracts ``SolanaContract``, its scanner ``SolanaRPC``
public final class SolanaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = SOLANA.Solana.chainId

    /// "Solana"
    public let userReadableName: String = "Solana"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<SolanaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// SOL, the chain's coin, under the placeholder address `sol`
    public let mainContract: SolanaContract!

    /// The contract at `address`, validated as base58 of 32 bytes, or the coin's placeholder; kept as given, since
    /// base58 is case-sensitive
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> SolanaContract {
        let contract = SolanaContract(address: address)
        guard contract == mainContract || SolanaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: SolanaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<SolanaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<SolanaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Solana's public JSON-RPC, `api.mainnet-beta.solana.com`
    public let scanner: SolanaRPC = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<SolanaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let solContractAddress = "sol"

    /// The one Solana chain
    public static let `default`: SolanaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.solContractAddress)
    }
}

public extension CryptoChain where Self == SolanaChain {
    /// The one Solana chain
    static var solana: SolanaChain { .default }
}
