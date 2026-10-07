// NervosChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Nervos, `CKB.Nervos.chainId`: its contracts ``NervosContract``, its scanner ``CKBExplorer``
public final class NervosChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = CKB.Nervos.chainId

    /// "Nervos"
    public let userReadableName: String = "Nervos"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<NervosContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// CKB, the chain's coin, under the placeholder address `ckb`
    public let mainContract: NervosContract!

    /// The contract at `address`, validated as an address, `ckb1` and at least 42 characters of bech32's alphabet in
    /// lower case, RFC 0021's full format (bech32m) or its deprecated short one (bech32), or the coin's placeholder;
    /// kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> NervosContract {
        let contract = NervosContract(address: address)
        guard contract == mainContract || NervosContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: NervosContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<NervosContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<NervosContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Nervos's public CKB Explorer API, `mainnet-api.explorer.nervos.org`, keyless
    public let scanner: CKBExplorer = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<NervosContract>? {
        tokens.withLock { $0?[address] }
    }

    static let ckbContractAddress = "ckb"

    /// The one Nervos chain
    public static let `default`: NervosChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ckbContractAddress)
    }
}

public extension CryptoChain where Self == NervosChain {
    /// The one Nervos chain
    static var nervos: NervosChain { .default }
}
