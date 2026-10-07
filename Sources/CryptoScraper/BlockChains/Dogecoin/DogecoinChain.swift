// DogecoinChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Dogecoin, `BIP122.Dogecoin.chainId`: its contracts ``DogecoinContract``, its scanner ``Blockchair``
public final class DogecoinChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Dogecoin.chainId

    /// "Dogecoin"
    public let userReadableName: String = "Dogecoin"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<DogecoinContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// DOGE, the chain's coin, under the placeholder address `doge`
    public let mainContract: DogecoinContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 30 (`D`) or 22 (`A` or `9`),
    /// or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> DogecoinContract {
        let contract = DogecoinContract(address: address)
        guard contract == mainContract || DogecoinContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: DogecoinContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<DogecoinContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<DogecoinContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Blockchair's public API, keyless, for its chain `dogecoin`
    public let scanner: Blockchair<DogecoinContract> = .init(slug: "dogecoin")

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<DogecoinContract>? {
        tokens.withLock { $0?[address] }
    }

    static let dogeContractAddress = "doge"

    /// The one Dogecoin chain
    public static let `default`: DogecoinChain = .init()

    private init() {
        self.mainContract = .init(address: Self.dogeContractAddress)
    }
}

public extension CryptoChain where Self == DogecoinChain {
    /// The one Dogecoin chain
    static var dogecoin: DogecoinChain { .default }
}
