// DecredChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Decred, `DCR.Decred.chainId`: its contracts ``DecredContract``, its scanner ``Dcrdata``
public final class DecredChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = DCR.Decred.chainId

    /// "Decred"
    public let userReadableName: String = "Decred"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<DecredContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// DCR, the chain's coin, under the placeholder address `dcr`
    public let mainContract: DecredContract!

    /// The contract at `address`, validated as an address, base58 decoding to a two-byte version and a 20-byte hash:
    /// `Ds` (0x073f), `Dc` (0x071a), `De` (0x071f) or `DS` (0x0701), as dcrd's mainnet parameters state them, or the
    /// coin's placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> DecredContract {
        let contract = DecredContract(address: address)
        guard contract == mainContract || DecredContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: DecredContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<DecredContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<DecredContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: dcrdata's public API, `dcrdata.decred.org`, keyless
    public let scanner: Dcrdata = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<DecredContract>? {
        tokens.withLock { $0?[address] }
    }

    static let dcrContractAddress = "dcr"

    /// The one Decred chain
    public static let `default`: DecredChain = .init()

    private init() {
        self.mainContract = .init(address: Self.dcrContractAddress)
    }
}

public extension CryptoChain where Self == DecredChain {
    /// The one Decred chain
    static var decred: DecredChain { .default }
}
