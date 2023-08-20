// EthereumChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class EthereumChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Ethereum"

    public var chainTokenInfos: Set<SimpleTokenInfo<EthereumContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: EthereumContract!

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

    private var tokens: [String: SimpleTokenInfo<EthereumContract>]?
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<EthereumContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            tokens![token.contractAddress.address] = token
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<EthereumContract>? {
        tokens?[address]
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
