// ZilliqaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Zilliqa, `ZIL.Zilliqa.chainId`: its contracts ``ZilliqaContract``, its scanner ``ZilliqaRPC``
public final class ZilliqaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = ZIL.Zilliqa.chainId

    /// "Zilliqa"
    public let userReadableName: String = "Zilliqa"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<ZilliqaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ZIL, the chain's coin, under the placeholder address `zil`
    public let mainContract: ZilliqaContract!

    /// The contract at `address`, validated as an address, bech32 `zil1` of 20 bytes in lower case, its checksum
    /// verified; a 20-byte hex address (`0x` and 40 hex digits) is accepted and written as its bech32, or the coin's
    /// placeholder; normalized to its bech32
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> ZilliqaContract {
        let contract = ZilliqaContract(address: address)
        guard contract == mainContract || ZilliqaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: ZilliqaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<ZilliqaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<ZilliqaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Zilliqa's public JSON-RPC, `api.zilliqa.com`, keyless
    public let scanner: ZilliqaRPC = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<ZilliqaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let zilContractAddress = "zil"

    /// The one Zilliqa chain
    public static let `default`: ZilliqaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.zilContractAddress)
    }
}

public extension CryptoChain where Self == ZilliqaChain {
    /// The one Zilliqa chain
    static var zilliqa: ZilliqaChain { .default }
}
