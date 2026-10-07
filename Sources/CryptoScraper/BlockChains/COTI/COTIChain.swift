// COTIChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// COTI, `EIP155.COTI.chainId`: an EVM chain, its contracts ``COTIContract``, on Optimism's pattern
public final class COTIChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.COTI.chainId

    /// "COTI"
    public let userReadableName: String = "COTI"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<COTIContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// COTI, the chain's coin, under the placeholder address `coti`
    public let mainContract: COTIContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> COTIContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: COTIContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<COTIContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<COTIContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Etherscan's API V2 does not serve `EIP155.COTI.chainId` (its chain list of
    /// 2026-10-07); zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<COTIContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<COTIContract>? {
        tokens.withLock { $0?[address] }
    }

    static let cotiContractAddress = "coti"

    /// The one COTI chain
    public static let `default`: COTIChain = .init()

    private init() {
        self.mainContract = .init(address: Self.cotiContractAddress)
    }
}

public extension CryptoChain where Self == COTIChain {
    /// The one COTI chain
    static var coti: COTIChain { .default }
}
