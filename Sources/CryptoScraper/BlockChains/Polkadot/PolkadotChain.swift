// PolkadotChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Polkadot, `POLKADOT.Polkadot.chainId`: its contracts ``PolkadotContract``, its scanner ``SubstrateSidecar``
public final class PolkadotChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = POLKADOT.Polkadot.chainId

    /// "Polkadot"
    public let userReadableName: String = "Polkadot"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<PolkadotContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// DOT, the chain's coin, under the placeholder address `dot`
    public let mainContract: PolkadotContract!

    /// The contract at `address`, validated as an account, SS58 of 32 bytes whose network prefix is 0, or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> PolkadotContract {
        let contract = PolkadotContract(address: address)
        guard contract == mainContract || PolkadotContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: PolkadotContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<PolkadotContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<PolkadotContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Parity's public Substrate API Sidecar for Polkadot,
    /// `polkadot-public-sidecar.parity-chains.parity.io`, keyless
    public let scanner: SubstrateSidecar<PolkadotContract> = .init(
        endPoint: URL(string: "https://polkadot-public-sidecar.parity-chains.parity.io")!
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<PolkadotContract>? {
        tokens.withLock { $0?[address] }
    }

    static let dotContractAddress = "dot"

    /// The one Polkadot chain
    public static let `default`: PolkadotChain = .init()

    private init() {
        self.mainContract = .init(address: Self.dotContractAddress)
    }
}

public extension CryptoChain where Self == PolkadotChain {
    /// The one Polkadot chain
    static var polkadot: PolkadotChain { .default }
}
