// ArweaveChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Arweave, `ARWEAVE.Arweave.chainId`: its contracts ``ArweaveContract``, its scanner ``ArweaveGateway``
public final class ArweaveChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = ARWEAVE.Arweave.chainId

    /// "Arweave"
    public let userReadableName: String = "Arweave"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<ArweaveContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// AR, the chain's coin, under the placeholder address `ar`
    public let mainContract: ArweaveContract!

    /// The contract at `address`, validated as 43 characters of base64url, or the coin's placeholder; kept as given,
    /// since base64url is case-sensitive
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> ArweaveContract {
        let contract = ArweaveContract(address: address)
        guard contract == mainContract || ArweaveContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: ArweaveContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<ArweaveContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<ArweaveContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: the public Arweave gateway, `arweave.net`
    public let scanner: ArweaveGateway = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<ArweaveContract>? {
        tokens.withLock { $0?[address] }
    }

    static let arContractAddress = "ar"

    /// The one Arweave chain
    public static let `default`: ArweaveChain = .init()

    private init() {
        self.mainContract = .init(address: Self.arContractAddress)
    }
}

public extension CryptoChain where Self == ArweaveChain {
    /// The one Arweave chain
    static var arweave: ArweaveChain { .default }
}
