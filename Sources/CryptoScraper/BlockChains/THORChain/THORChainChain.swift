// THORChainChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// THORChain, `COSMOS.THORChain.chainId`: its contracts ``THORChainContract``, its scanner ``CosmosLCD``
public final class THORChainChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = COSMOS.THORChain.chainId

    /// "THORChain"
    public let userReadableName: String = "THORChain"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<THORChainContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// RUNE, the chain's coin, under the placeholder address `rune`
    public let mainContract: THORChainContract!

    /// The contract at `address`, validated as an account, bech32 `thor1` and 38 characters (20 bytes) or 58 (32 bytes,
    /// a contract), in lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits, or the coin's placeholder;
    /// kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> THORChainContract {
        let contract = THORChainContract(address: address)
        guard contract == mainContract || THORChainContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: THORChainContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<THORChainContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<THORChainContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: cosmos.directory's public LCD for THORChain, `rest.cosmos.directory/thorchain`, keyless,
    /// reading the coin as `rune`
    public let scanner: CosmosLCD<THORChainContract> = .init(
        endPoint: URL(string: "https://rest.cosmos.directory/thorchain")!, denom: "rune"
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<THORChainContract>? {
        tokens.withLock { $0?[address] }
    }

    static let runeContractAddress = "rune"

    /// The one THORChain chain
    public static let `default`: THORChainChain = .init()

    private init() {
        self.mainContract = .init(address: Self.runeContractAddress)
    }
}

public extension CryptoChain where Self == THORChainChain {
    /// The one THORChain chain
    static var thorChain: THORChainChain { .default }
}
