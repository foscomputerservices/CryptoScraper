// StellarChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Stellar, `STELLAR.Stellar.chainId`: its contracts ``StellarContract``, its scanner ``Horizon``
public final class StellarChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = STELLAR.Stellar.chainId

    /// "Stellar"
    public let userReadableName: String = "Stellar"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<StellarContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// XLM, the chain's coin, under the placeholder address `xlm`
    public let mainContract: StellarContract!

    /// The contract at `address`, validated as a StrKey account (`G…`) or contract (`C…`), 56 characters of upper-case
    /// base32, a
    /// classic asset as `<code>-<issuer>` (CoinGecko's form), or the coin's placeholder; kept as given, since StrKey is
    /// upper-case only
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> StellarContract {
        let contract = StellarContract(address: address)
        guard contract == mainContract || StellarContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: StellarContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<StellarContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<StellarContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Horizon, Stellar's public API, `horizon.stellar.org`
    public let scanner: Horizon = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<StellarContract>? {
        tokens.withLock { $0?[address] }
    }

    static let xlmContractAddress = "xlm"

    /// The one Stellar chain
    public static let `default`: StellarChain = .init()

    private init() {
        self.mainContract = .init(address: Self.xlmContractAddress)
    }
}

public extension CryptoChain where Self == StellarChain {
    /// The one Stellar chain
    static var stellar: StellarChain { .default }
}
