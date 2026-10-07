// RavencoinChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Ravencoin, `BIP122.Ravencoin.chainId`: its contracts ``RavencoinContract``, its scanner ``NilScanner``
public final class RavencoinChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Ravencoin.chainId

    /// "Ravencoin"
    public let userReadableName: String = "Ravencoin"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<RavencoinContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// RVN, the chain's coin, under the placeholder address `rvn`
    public let mainContract: RavencoinContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 60 (`R`) or 122 (`r`), or the
    /// coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> RavencoinContract {
        let contract = RavencoinContract(address: address)
        guard contract == mainContract || RavencoinContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: RavencoinContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<RavencoinContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<RavencoinContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Blockchair does not serve the chain (its `/stats` of 2026-10-07) and no
    /// keyless explorer of the chain's own was recorded; zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<RavencoinContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<RavencoinContract>? {
        tokens.withLock { $0?[address] }
    }

    static let rvnContractAddress = "rvn"

    /// The one Ravencoin chain
    public static let `default`: RavencoinChain = .init()

    private init() {
        self.mainContract = .init(address: Self.rvnContractAddress)
    }
}

public extension CryptoChain where Self == RavencoinChain {
    /// The one Ravencoin chain
    static var ravencoin: RavencoinChain { .default }
}
