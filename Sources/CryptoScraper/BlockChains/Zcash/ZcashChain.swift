// ZcashChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Zcash, `BIP122.Zcash.chainId`: its contracts ``ZcashContract``, its scanner ``Blockchair``
public final class ZcashChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Zcash.chainId

    /// "Zcash"
    public let userReadableName: String = "Zcash"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<ZcashContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ZEC, the chain's coin, under the placeholder address `zec`
    public let mainContract: ZcashContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 0x1cb8 (`t1`) or 0x1cbd
    /// (`t3`), or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/shieldedAddress(_:)`` for a shielded address,
    ///   ``BlockChainError/malformedAddress(_:)`` for any other
    public func contract(for address: String) throws -> ZcashContract {
        guard !ZcashContract.isShielded(address) else {
            throw BlockChainError.shieldedAddress(address)
        }
        let contract = ZcashContract(address: address)
        guard contract == mainContract || ZcashContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: ZcashContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<ZcashContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<ZcashContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Blockchair's public API, keyless, for its chain `zcash`
    public let scanner: Blockchair<ZcashContract> = .init(slug: "zcash")

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<ZcashContract>? {
        tokens.withLock { $0?[address] }
    }

    static let zecContractAddress = "zec"

    /// The one Zcash chain
    public static let `default`: ZcashChain = .init()

    private init() {
        self.mainContract = .init(address: Self.zecContractAddress)
    }
}

public extension CryptoChain where Self == ZcashChain {
    /// The one Zcash chain
    static var zcash: ZcashChain { .default }
}
