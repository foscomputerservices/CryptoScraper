// SiaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Sia, `SIA.Sia.chainId`: its contracts ``SiaContract``, its scanner ``SiaScan``
public final class SiaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = SIA.Sia.chainId

    /// "Sia"
    public let userReadableName: String = "Sia"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<SiaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// SC, the chain's coin, under the placeholder address `sc`
    public let mainContract: SiaContract!

    /// The contract at `address`, validated as an address, 76 hex digits (a 32-byte hash and its 6-byte checksum),
    /// lower-cased, or the coin's placeholder; lower-cased
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> SiaContract {
        let contract = SiaContract(address: address)
        guard contract == mainContract || SiaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: SiaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<SiaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<SiaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: SiaScan's public explorer API, `api.siascan.com`, keyless
    public let scanner: SiaScan = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<SiaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let scContractAddress = "sc"

    /// The one Sia chain
    public static let `default`: SiaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.scContractAddress)
    }
}

public extension CryptoChain where Self == SiaChain {
    /// The one Sia chain
    static var sia: SiaChain { .default }
}
