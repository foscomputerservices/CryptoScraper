// FantomChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

public final class FantomChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.Fantom.chainId

    public let userReadableName: String = "Fantom"

    public var chainTokenInfos: Set<SimpleTokenInfo<FantomContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: FantomContract!

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

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<FantomContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<FantomContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<FantomContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: FTMScan = .init()

    static let ftmContractAddress = "ftm"

    public static let `default`: FantomChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ftmContractAddress)
    }
}

public extension CryptoChain where Self == FantomChain {
    static var fantom: FantomChain { .default }
}
