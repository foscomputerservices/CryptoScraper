// NeoChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Neo, `NEO.Neo.chainId`: its contracts ``NeoContract``, its scanner ``NeoRPC``
public final class NeoChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = NEO.Neo.chainId

    /// "Neo"
    public let userReadableName: String = "Neo"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<NeoContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// NEO, the chain's coin, under the placeholder address `neo`
    public let mainContract: NeoContract!

    /// The contract at `address`, validated as an address (`N` and 33 more characters of base58) or a script hash (`0x`
    /// and 40 hex digits), or one of the two coins' placeholders; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> NeoContract {
        let contract = NeoContract(address: address)
        guard contract == mainContract || contract.address == Self.gasContractAddress || NeoContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: NeoContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<NeoContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<NeoContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: a public Neo N3 node's JSON-RPC, `mainnet1.neo.coz.io`
    public let scanner: NeoRPC = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<NeoContract>? {
        tokens.withLock { $0?[address] }
    }

    static let neoContractAddress = "neo"

    static let gasContractAddress = "gas"

    /// The one Neo chain
    public static let `default`: NeoChain = .init()

    private init() {
        self.mainContract = .init(address: Self.neoContractAddress)
    }
}

public extension CryptoChain where Self == NeoChain {
    /// The one Neo chain
    static var neo: NeoChain { .default }
}
