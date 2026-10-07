// CosmosHubChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Cosmos Hub, `COSMOS.CosmosHub.chainId`: its contracts ``CosmosHubContract``, its scanner ``CosmosLCD``
public final class CosmosHubChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = COSMOS.CosmosHub.chainId

    /// "Cosmos Hub"
    public let userReadableName: String = "Cosmos Hub"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<CosmosHubContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ATOM, the chain's coin, under the placeholder address `atom`
    public let mainContract: CosmosHubContract!

    /// The contract at `address`, validated as an account, bech32 `cosmos1` and 38 characters (20 bytes) or 58 (32
    /// bytes, a contract), in lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits, or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> CosmosHubContract {
        let contract = CosmosHubContract(address: address)
        guard contract == mainContract || CosmosHubContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: CosmosHubContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<CosmosHubContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<CosmosHubContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: cosmos.directory's public LCD for the Cosmos Hub, `rest.cosmos.directory/cosmoshub`,
    /// keyless, reading the coin as `uatom`
    public let scanner: CosmosLCD<CosmosHubContract> = .init(
        endPoint: URL(string: "https://rest.cosmos.directory/cosmoshub")!, denom: "uatom"
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<CosmosHubContract>? {
        tokens.withLock { $0?[address] }
    }

    static let atomContractAddress = "atom"

    /// The one Cosmos Hub chain
    public static let `default`: CosmosHubChain = .init()

    private init() {
        self.mainContract = .init(address: Self.atomContractAddress)
    }
}

public extension CryptoChain where Self == CosmosHubChain {
    /// The one Cosmos Hub chain
    static var cosmosHub: CosmosHubChain { .default }
}
