// FantomChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class FantomChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Fantom"

    public var chainTokenInfos: Set<SimpleTokenInfo<FantomContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: FantomContract!

    public func contract(for address: String) throws -> FantomContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: FantomContract.self
            )
        )
    }

    private var tokens: [String: SimpleTokenInfo<FantomContract>]?
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<FantomContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            tokens![token.contractAddress.address] = token
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<FantomContract>? {
        tokens?[address]
    }

    public let scanner: FTMScan? = .init()

    static let ftmContractAddress = "ftm"

    public static let `default`: FantomChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ftmContractAddress)
    }
}

public extension CryptoChain where Self == FantomChain {
    static var fantom: FantomChain { .default }
}
