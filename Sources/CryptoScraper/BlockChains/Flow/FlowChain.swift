// FlowChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Flow, `FLOW.Flow.chainId`: its contracts ``FlowContract``, its scanner ``FlowAccessAPI``
public final class FlowChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = FLOW.Flow.chainId

    /// "Flow"
    public let userReadableName: String = "Flow"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<FlowContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// FLOW, the chain's coin, under the placeholder address `flow`
    public let mainContract: FlowContract!

    /// The contract at `address`, validated as an account (`0x` and 16 hex digits) or a contract `A.<16 hex
    /// digits>.<ContractName>`, or the coin's placeholder; an account's hex lower-cased, since it is a number
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> FlowContract {
        let contract = FlowContract(address: address)
        guard contract == mainContract || FlowContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: FlowContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<FlowContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<FlowContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Flow's public Access API over REST, `rest-mainnet.onflow.org`
    public let scanner: FlowAccessAPI = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<FlowContract>? {
        tokens.withLock { $0?[address] }
    }

    static let flowContractAddress = "flow"

    /// The one Flow chain
    public static let `default`: FlowChain = .init()

    private init() {
        self.mainContract = .init(address: Self.flowContractAddress)
    }
}

public extension CryptoChain where Self == FlowChain {
    /// The one Flow chain
    static var flow: FlowChain { .default }
}
