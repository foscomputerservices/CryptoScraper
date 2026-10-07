// FetchAIChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Fetch.ai, `COSMOS.FetchAI.chainId`: its contracts ``FetchAIContract``, its scanner ``CosmosLCD``
public final class FetchAIChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = COSMOS.FetchAI.chainId

    /// "Fetch.ai"
    public let userReadableName: String = "Fetch.ai"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<FetchAIContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// FET, the chain's coin, under the placeholder address `fet`
    public let mainContract: FetchAIContract!

    /// The contract at `address`, validated as an account, bech32 `fetch1` and 38 characters (20 bytes) or 58 (32
    /// bytes, a contract), in lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits, or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> FetchAIContract {
        let contract = FetchAIContract(address: address)
        guard contract == mainContract || FetchAIContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: FetchAIContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<FetchAIContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<FetchAIContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Fetch.ai's public LCD, `rest-fetchhub.fetch.ai`, keyless, reading the coin as `afet`
    public let scanner: CosmosLCD<FetchAIContract> = .init(
        endPoint: URL(string: "https://rest-fetchhub.fetch.ai")!, denom: "afet"
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<FetchAIContract>? {
        tokens.withLock { $0?[address] }
    }

    static let fetContractAddress = "fet"

    /// The one Fetch.ai chain
    public static let `default`: FetchAIChain = .init()

    private init() {
        self.mainContract = .init(address: Self.fetContractAddress)
    }
}

public extension CryptoChain where Self == FetchAIChain {
    /// The one Fetch.ai chain
    static var fetchAI: FetchAIChain { .default }
}
