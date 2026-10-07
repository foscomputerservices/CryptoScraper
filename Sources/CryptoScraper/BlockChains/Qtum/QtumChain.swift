// QtumChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Qtum, `BIP122.Qtum.chainId`: its contracts ``QtumContract``, its scanner ``NilScanner``
public final class QtumChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.Qtum.chainId

    /// "Qtum"
    public let userReadableName: String = "Qtum"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<QtumContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// QTUM, the chain's coin, under the placeholder address `qtum`
    public let mainContract: QtumContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 58 (`Q`) or 50 (`M`), or a
    /// segregated-witness address, `qc1` in lower case, or a QRC-20 contract, 40 hex digits, or the coin's placeholder;
    /// normalized as the contract normalizes it
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> QtumContract {
        let contract = QtumContract(address: address)
        guard contract == mainContract || QtumContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: QtumContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<QtumContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<QtumContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Blockchair does not serve the chain (its `/stats` of 2026-10-07) and no
    /// keyless explorer of the chain's own was recorded; zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<QtumContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<QtumContract>? {
        tokens.withLock { $0?[address] }
    }

    static let qtumContractAddress = "qtum"

    /// The one Qtum chain
    public static let `default`: QtumChain = .init()

    private init() {
        self.mainContract = .init(address: Self.qtumContractAddress)
    }
}

public extension CryptoChain where Self == QtumChain {
    /// The one Qtum chain
    static var qtum: QtumChain { .default }
}
