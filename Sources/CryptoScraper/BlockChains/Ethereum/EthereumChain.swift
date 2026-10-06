// EthereumChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

public final class EthereumChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    public let userReadableName: String = "Ethereum"

    public var chainTokenInfos: Set<SimpleTokenInfo<EthereumContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: EthereumContract!

    public func contract(for address: String) throws -> EthereumContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: EthereumContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<EthereumContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<EthereumContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<EthereumContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: Etherscan? = .init()

    static let ethContractAddress = "eth"

    public static let `default`: EthereumChain = .init()

    private init() {
        self.mainContract = EthereumContract(address: Self.ethContractAddress)
    }
}

public extension CryptoChain where Self == EthereumChain {
    static var ethereum: EthereumChain { .default }
}
