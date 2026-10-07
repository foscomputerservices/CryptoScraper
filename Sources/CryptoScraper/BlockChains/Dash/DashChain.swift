// DashChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Dash, `BIP122.Dash.chainId`: its contracts ``DashContract``, its scanner ``Blockchair``
public final class DashChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Dash.chainId

    /// "Dash"
    public let userReadableName: String = "Dash"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<DashContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// DASH, the chain's coin, under the placeholder address `dash`
    public let mainContract: DashContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 76 (`X`) or 16 (`7`), or the
    /// coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> DashContract {
        let contract = DashContract(address: address)
        guard contract == mainContract || DashContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: DashContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<DashContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<DashContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Blockchair's public API, keyless, for its chain `dash`
    public let scanner: Blockchair<DashContract> = .init(slug: "dash")

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<DashContract>? {
        tokens.withLock { $0?[address] }
    }

    static let dashContractAddress = "dash"

    /// The one Dash chain
    public static let `default`: DashChain = .init()

    private init() {
        self.mainContract = .init(address: Self.dashContractAddress)
    }
}

public extension CryptoChain where Self == DashChain {
    /// The one Dash chain
    static var dash: DashChain { .default }
}
