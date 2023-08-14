// PolygonChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class PolygonChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Matic"

    public var chainTokenInfos: Set<SimpleTokenInfo<MaticContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: MaticContract!

    public func contract(for address: String) throws -> MaticContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: MaticContract.self
            )
        )
    }

    private var tokens: [String: SimpleTokenInfo<MaticContract>]?
    private func loadChainTokens<Tokens>(from newTokens: Tokens) where Tokens: Collection<SimpleTokenInfo<MaticContract>> {
        tokens = tokens ?? [:]

        for token in newTokens {
            tokens![token.contractAddress.address] = token
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<MaticContract>? {
        tokens?[address]
    }

    public let scanner: PolygonScan? = .init()

    static let maticContractAddress = "matic"

    public static let `default`: PolygonChain = .init()

    private init() {
        self.mainContract = .init(address: Self.maticContractAddress)
    }
}

public extension CryptoChain where Self == PolygonChain {
    static var polygon: PolygonChain { .default }
}
