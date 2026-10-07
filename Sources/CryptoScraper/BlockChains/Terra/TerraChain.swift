// TerraChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Terra, `COSMOS.Terra.chainId`: its contracts ``TerraContract``, its scanner ``CosmosLCD``
public final class TerraChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = COSMOS.Terra.chainId

    /// "Terra"
    public let userReadableName: String = "Terra"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<TerraContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// LUNA, the chain's coin, under the placeholder address `luna`
    public let mainContract: TerraContract!

    /// The contract at `address`, validated as an account, bech32 `terra1` and 38 characters (20 bytes) or 58 (32
    /// bytes, a contract), in lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits, or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> TerraContract {
        let contract = TerraContract(address: address)
        guard contract == mainContract || TerraContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: TerraContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<TerraContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<TerraContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: cosmos.directory's public LCD for Terra, `rest.cosmos.directory/terra2`, keyless, reading
    /// the coin as `uluna`
    public let scanner: CosmosLCD<TerraContract> = .init(
        endPoint: URL(string: "https://rest.cosmos.directory/terra2")!, denom: "uluna"
    )

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<TerraContract>? {
        tokens.withLock { $0?[address] }
    }

    static let lunaContractAddress = "luna"

    /// The one Terra chain
    public static let `default`: TerraChain = .init()

    private init() {
        self.mainContract = .init(address: Self.lunaContractAddress)
    }
}

public extension CryptoChain where Self == TerraChain {
    /// The one Terra chain
    static var terra: TerraChain { .default }
}
