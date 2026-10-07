// PolygonChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

public final class PolygonChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Polygon.chainId

    public let userReadableName: String = "Matic"

    public var chainTokenInfos: Set<SimpleTokenInfo<MaticContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: MaticContract!

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

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<MaticContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<MaticContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<MaticContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: PolygonScan = .init()

    static let maticContractAddress = "matic"

    public static let `default`: PolygonChain = .init()

    private init() {
        self.mainContract = .init(address: Self.maticContractAddress)
    }
}

public extension CryptoChain where Self == PolygonChain {
    static var polygon: PolygonChain { .default }
}
