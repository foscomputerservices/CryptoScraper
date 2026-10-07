// ECashChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// eCash, `BIP122.ECash.chainId`: its contracts ``ECashContract``, its scanner ``NilScanner``
public final class ECashChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = BIP122.ECash.chainId

    /// "eCash"
    public let userReadableName: String = "eCash"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<ECashContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// XEC, the chain's coin, under the placeholder address `xec`
    public let mainContract: ECashContract!

    /// The contract at `address`, validated as a CashAddr, `ecash:` and `q` or `p` and 41 more characters, all in lower or all in upper case, its prefix optional, or a legacy address, base58 of a 20-byte hash whose version is 0 (`1`) or 5 (`3`), or the coin's placeholder; normalized as the contract normalizes it
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> ECashContract {
        let contract = ECashContract(address: address)
        guard contract == mainContract || ECashContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: ECashContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<ECashContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<ECashContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none. Blockchair serves the chain (`ecash`, its `/stats` of 2026-10-07), but refused
    /// every address read when recorded (430, the IP rate-limited), so no answer of its was seen; zero balances and no
    /// transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<ECashContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<ECashContract>? {
        tokens.withLock { $0?[address] }
    }

    static let xecContractAddress = "xec"

    /// The one eCash chain
    public static let `default`: ECashChain = .init()

    private init() {
        self.mainContract = .init(address: Self.xecContractAddress)
    }
}

public extension CryptoChain where Self == ECashChain {
    /// The one eCash chain
    static var eCash: ECashChain { .default }
}
