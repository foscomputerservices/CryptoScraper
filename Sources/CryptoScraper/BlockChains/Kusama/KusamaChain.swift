// KusamaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Kusama, `POLKADOT.Kusama.chainId`: its contracts ``KusamaContract``, its scanner ``SubstrateSidecar``
public final class KusamaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = POLKADOT.Kusama.chainId

    /// "Kusama"
    public let userReadableName: String = "Kusama"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<KusamaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// KSM, the chain's coin, under the placeholder address `ksm`
    public let mainContract: KusamaContract!

    /// The contract at `address`, validated as an account, SS58 of 32 bytes whose network prefix is 2, or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> KusamaContract {
        let contract = KusamaContract(address: address)
        guard contract == mainContract || KusamaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: KusamaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<KusamaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<KusamaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Parity's public Substrate API Sidecar for Kusama,
    /// `kusama-public-sidecar.parity-chains.parity.io`, keyless
    public let scanner: SubstrateSidecar<KusamaContract> = .init(
        endPoint: URL(string: "https://kusama-public-sidecar.parity-chains.parity.io")!
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<KusamaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let ksmContractAddress = "ksm"

    /// The one Kusama chain
    public static let `default`: KusamaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ksmContractAddress)
    }
}

public extension CryptoChain where Self == KusamaChain {
    /// The one Kusama chain
    static var kusama: KusamaChain { .default }
}
