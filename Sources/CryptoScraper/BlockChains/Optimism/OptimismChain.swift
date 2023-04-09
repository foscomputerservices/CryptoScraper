// OptimismChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class OptimismChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Optimism"

    public var chainTokenInfos: Set<SimpleTokenInfo<OptimismContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: OptimismContract!

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

    private var tokens: [String: SimpleTokenInfo<OptimismContract>]?
    private func loadChainTokens(from newTokens: any Collection<SimpleTokenInfo<OptimismContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            // I do not understand why the next line is needed 🤷‍♂️
            let token = token as! SimpleTokenInfo<OptimismContract>
            tokens![token.contractAddress.address] = token
        }
    }

    public let scanner: OptimisticEtherscan? = .init()

    public func tokenInfo(for address: String) -> SimpleTokenInfo<OptimismContract>? {
        tokens?[address]
    }

    static let opContractAddress = "OP"

    public static let `default`: OptimismChain = .init()

    private init() {
        self.mainContract = .init(address: Self.opContractAddress)
    }
}

public extension CryptoChain where Self == OptimismChain {
    static var optimism: OptimismChain { .default }
}
