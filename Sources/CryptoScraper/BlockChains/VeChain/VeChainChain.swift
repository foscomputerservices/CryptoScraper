// VeChainChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// VeChain, `VECHAIN.VeChain.chainId`: its contracts ``VeChainContract``, its scanner ``VeChainThor``
public final class VeChainChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = VECHAIN.VeChain.chainId

    /// "VeChain"
    public let userReadableName: String = "VeChain"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<VeChainContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// VET, the chain's coin, under the placeholder address `vet`
    public let mainContract: VeChainContract!

    /// The contract at `address`, validated as `0x` and 40 hex digits, or one of the two coins' placeholders;
    /// lower-cased, as the EVM chains' addresses are
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> VeChainContract {
        let contract = VeChainContract(address: address)
        guard contract == mainContract || contract.address == Self.vthoContractAddress || VeChainContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: VeChainContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<VeChainContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<VeChainContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: a public VeChainThor node's REST API, `mainnet.vechain.org`
    public let scanner: VeChainThor = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<VeChainContract>? {
        tokens.withLock { $0?[address] }
    }

    static let vetContractAddress = "vet"

    static let vthoContractAddress = "vtho"

    /// The one VeChain chain
    public static let `default`: VeChainChain = .init()

    private init() {
        self.mainContract = .init(address: Self.vetContractAddress)
    }
}

public extension CryptoChain where Self == VeChainChain {
    /// The one VeChain chain
    static var veChain: VeChainChain { .default }
}
