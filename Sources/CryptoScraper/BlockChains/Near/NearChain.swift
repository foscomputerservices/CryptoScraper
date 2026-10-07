// NearChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// NEAR, `NEAR.Near.chainId`: its contracts ``NearContract``, its scanner ``NearRPC``
public final class NearChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = NEAR.Near.chainId

    /// "NEAR"
    public let userReadableName: String = "NEAR"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<NearContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// NEAR, the chain's coin, under the placeholder address `near`
    public let mainContract: NearContract!

    /// The contract at `address`, validated as an account id: a named account (2 to 64 characters, lower-case letters
    /// and digits in parts joined by `.`, each part's characters joined by single `-` or `_`, as `wrap.near`) or an
    /// implicit account (64 lower-case hex digits), each written in lower case only, or the coin's placeholder; kept as
    /// given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> NearContract {
        let contract = NearContract(address: address)
        guard contract == mainContract || NearContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: NearContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<NearContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<NearContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: NEAR's public RPC, `rpc.mainnet.near.org`, keyless, and NearBlocks' keyless API for
    /// transactions
    public let scanner: NearRPC = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<NearContract>? {
        tokens.withLock { $0?[address] }
    }

    static let nearContractAddress = "near"

    /// The one NEAR chain
    public static let `default`: NearChain = .init()

    private init() {
        self.mainContract = .init(address: Self.nearContractAddress)
    }
}

public extension CryptoChain where Self == NearChain {
    /// The one NEAR chain
    static var near: NearChain { .default }
}
