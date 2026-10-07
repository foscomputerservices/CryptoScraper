// BitcoinCashChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Bitcoin Cash, `BIP122.BitcoinCash.chainId`: its contracts ``BitcoinCashContract``, its scanner ``Blockchair``
public final class BitcoinCashChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.BitcoinCash.chainId

    /// "Bitcoin Cash"
    public let userReadableName: String = "Bitcoin Cash"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<BitcoinCashContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// BCH, the chain's coin, under the placeholder address `bch`
    public let mainContract: BitcoinCashContract!

    /// The contract at `address`, validated as a CashAddr, `bitcoincash:` and `q` or `p` and 41 more characters, all in
    /// lower or all in upper case, its prefix optional, or a legacy address, base58 of a 20-byte hash whose version is
    /// 0 (`1`) or 5 (`3`), or the coin's placeholder; normalized as the contract normalizes it
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> BitcoinCashContract {
        let contract = BitcoinCashContract(address: address)
        guard contract == mainContract || BitcoinCashContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: BitcoinCashContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<BitcoinCashContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<BitcoinCashContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Blockchair's public API, keyless, for its chain `bitcoin-cash`; a CashAddr is asked for
    /// with its prefix
    public let scanner: Blockchair<BitcoinCashContract> = .init(slug: "bitcoin-cash", apiAddress: { $0.cashAddress })

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<BitcoinCashContract>? {
        tokens.withLock { $0?[address] }
    }

    static let bchContractAddress = "bch"

    /// The one Bitcoin Cash chain
    public static let `default`: BitcoinCashChain = .init()

    private init() {
        self.mainContract = .init(address: Self.bchContractAddress)
    }
}

public extension CryptoChain where Self == BitcoinCashChain {
    /// The one Bitcoin Cash chain
    static var bitcoinCash: BitcoinCashChain { .default }
}
