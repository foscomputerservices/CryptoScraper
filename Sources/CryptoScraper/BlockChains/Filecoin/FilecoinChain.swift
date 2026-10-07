// FilecoinChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Filecoin, `FIL.Filecoin.chainId`: its contracts ``FilecoinContract``, its scanner ``Filfox``
public final class FilecoinChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = FIL.Filecoin.chainId

    /// "Filecoin"
    public let userReadableName: String = "Filecoin"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<FilecoinContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// FIL, the chain's coin, under the placeholder address `fil`
    public let mainContract: FilecoinContract!

    /// The contract at `address`, validated as a mainnet address (`f0` and an actor id; `f1` or `f2` and 39, `f3` and
    /// 84 characters of lower-case base32; `f4`, a namespace actor id, `f` and lower-case base32), or the coin's
    /// placeholder; kept as given, since Filecoin writes its addresses in lower case
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> FilecoinContract {
        let contract = FilecoinContract(address: address)
        guard contract == mainContract || FilecoinContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: FilecoinContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<FilecoinContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<FilecoinContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Filfox's public API, `filfox.info/api/v1`
    public let scanner: Filfox = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<FilecoinContract>? {
        tokens.withLock { $0?[address] }
    }

    static let filContractAddress = "fil"

    /// The one Filecoin chain
    public static let `default`: FilecoinChain = .init()

    private init() {
        self.mainContract = .init(address: Self.filContractAddress)
    }
}

public extension CryptoChain where Self == FilecoinChain {
    /// The one Filecoin chain
    static var filecoin: FilecoinChain { .default }
}
