// VergeChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Verge, `BIP122.Verge.chainId`: its contracts ``VergeContract``, its scanner ``NilScanner``
public final class VergeChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Verge.chainId

    /// "Verge"
    public let userReadableName: String = "Verge"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<VergeContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// XVG, the chain's coin, under the placeholder address `xvg`
    public let mainContract: VergeContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 30 (`D`) or 33 (`E`), or a
    /// segregated-witness address, `vg1` in lower case, or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> VergeContract {
        let contract = VergeContract(address: address)
        guard contract == mainContract || VergeContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: VergeContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<VergeContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<VergeContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Blockchair does not serve the chain (its `/stats` of 2026-10-07) and no
    /// keyless explorer of the chain's own was recorded; zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<VergeContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<VergeContract>? {
        tokens.withLock { $0?[address] }
    }

    static let xvgContractAddress = "xvg"

    /// The one Verge chain
    public static let `default`: VergeChain = .init()

    private init() {
        self.mainContract = .init(address: Self.xvgContractAddress)
    }
}

public extension CryptoChain where Self == VergeChain {
    /// The one Verge chain
    static var verge: VergeChain { .default }
}
