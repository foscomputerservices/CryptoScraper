// OptimismChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

public final class OptimismChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    public let userReadableName: String = "Optimism"

    public var chainTokenInfos: Set<SimpleTokenInfo<OptimismContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: OptimismContract!

    public func contract(for address: String) throws -> OptimismContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: OptimismContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<OptimismContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<OptimismContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public let scanner: OptimisticEtherscan? = .init()

    public func tokenInfo(for address: String) -> SimpleTokenInfo<OptimismContract>? {
        tokens.withLock { $0?[address] }
    }

    static let opContractAddress = EthereumChain.ethContractAddress // ETH is the chain token

    public static let `default`: OptimismChain = .init()

    private init() {
        self.mainContract = .init(address: Self.opContractAddress)
    }
}

public extension CryptoChain where Self == OptimismChain {
    static var optimism: OptimismChain { .default }
}
