// StacksChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Stacks, `STACKS.Stacks.chainId`: its contracts ``StacksContract``, its scanner ``Hiro``
public final class StacksChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = STACKS.Stacks.chainId

    /// "Stacks"
    public let userReadableName: String = "Stacks"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<StacksContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// STX, the chain's coin, under the placeholder address `stx`
    public let mainContract: StacksContract!

    /// The contract at `address`, validated as a principal (`SP` or `SM` and c32check, 23 to 41 characters: c32check
    /// writes each leading zero byte as one `0`) or a contract `<principal>.<contract-name>`, or the coin's
    /// placeholder; kept as given, since c32check is upper-case only
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> StacksContract {
        let contract = StacksContract(address: address)
        guard contract == mainContract || StacksContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: StacksContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<StacksContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<StacksContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Hiro's public Stacks API, `api.hiro.so`
    public let scanner: Hiro = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<StacksContract>? {
        tokens.withLock { $0?[address] }
    }

    static let stxContractAddress = "stx"

    /// The one Stacks chain
    public static let `default`: StacksChain = .init()

    private init() {
        self.mainContract = .init(address: Self.stxContractAddress)
    }
}

public extension CryptoChain where Self == StacksChain {
    /// The one Stacks chain
    static var stacks: StacksChain { .default }
}
