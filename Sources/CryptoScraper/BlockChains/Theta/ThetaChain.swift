// ThetaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Theta, `EIP155.Theta.chainId`: an EVM chain, its contracts ``ThetaContract``, on Optimism's pattern
public final class ThetaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Theta.chainId

    /// "Theta"
    public let userReadableName: String = "Theta"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<ThetaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// TFUEL (Theta Fuel), the chain's coin, under the placeholder address `tfuel`
    public let mainContract: ThetaContract!

    /// The contract at `address`, lower-cased as every EVM address on this chain
    public func contract(for address: String) throws -> ThetaContract {
        .init(address: address)
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: ThetaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<ThetaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<ThetaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: none, since Etherscan's API V2 does not serve `EIP155.Theta.chainId` (its chain list of
    /// 2026-10-07); zero balances and no transactions, as ``NilScanner`` answers
    public let scanner: NilScanner<ThetaContract> = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<ThetaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let tfuelContractAddress = "tfuel"

    /// The one Theta chain
    public static let `default`: ThetaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.tfuelContractAddress)
    }
}

public extension CryptoChain where Self == ThetaChain {
    /// The one Theta chain
    static var theta: ThetaChain { .default }
}
