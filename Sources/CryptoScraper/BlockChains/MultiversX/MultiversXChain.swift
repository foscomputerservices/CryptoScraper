// MultiversXChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// MultiversX, `MVX.MultiversX.chainId`: its contracts ``MultiversXContract``, its scanner ``MultiversXAPI``
public final class MultiversXChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = MVX.MultiversX.chainId

    /// "MultiversX"
    public let userReadableName: String = "MultiversX"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<MultiversXContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// EGLD, the chain's coin, under the placeholder address `egld`
    public let mainContract: MultiversXContract!

    /// The contract at `address`, validated as an address (`erd1` and 58 characters of bech32's lower-case alphabet) or
    /// an ESDT token identifier (`<TICKER>-<6 hex digits>`), or the coin's placeholder; kept as given, since bech32 is
    /// lower case and an identifier is case-sensitive
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> MultiversXContract {
        let contract = MultiversXContract(address: address)
        guard contract == mainContract || MultiversXContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: MultiversXContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<MultiversXContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<MultiversXContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: MultiversX's public API, `api.multiversx.com`
    public let scanner: MultiversXAPI = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<MultiversXContract>? {
        tokens.withLock { $0?[address] }
    }

    static let egldContractAddress = "egld"

    /// The one MultiversX chain
    public static let `default`: MultiversXChain = .init()

    private init() {
        self.mainContract = .init(address: Self.egldContractAddress)
    }
}

public extension CryptoChain where Self == MultiversXChain {
    /// The one MultiversX chain
    static var multiversX: MultiversXChain { .default }
}
