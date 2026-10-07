// DigiByteChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// DigiByte, `BIP122.DigiByte.chainId`: its contracts ``DigiByteContract``, its scanner ``NilScanner``
public final class DigiByteChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.DigiByte.chainId

    /// "DigiByte"
    public let userReadableName: String = "DigiByte"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<DigiByteContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// DGB, the chain's coin, under the placeholder address `dgb`
    public let mainContract: DigiByteContract!

    /// The contract at `address`, validated as base58 of a 20-byte hash whose version is 30 (`D`), 63 (`S`) or 5 (`3`),
    /// or a segregated-witness address, `dgb1` in lower case, or the coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> DigiByteContract {
        let contract = DigiByteContract(address: address)
        guard contract == mainContract || DigiByteContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: DigiByteContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<DigiByteContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<DigiByteContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Blockchair does not serve the chain (its `/stats` of 2026-10-07) and no
    /// keyless explorer of the chain's own was recorded; zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<DigiByteContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<DigiByteContract>? {
        tokens.withLock { $0?[address] }
    }

    static let dgbContractAddress = "dgb"

    /// The one DigiByte chain
    public static let `default`: DigiByteChain = .init()

    private init() {
        self.mainContract = .init(address: Self.dgbContractAddress)
    }
}

public extension CryptoChain where Self == DigiByteChain {
    /// The one DigiByte chain
    static var digiByte: DigiByteChain { .default }
}
