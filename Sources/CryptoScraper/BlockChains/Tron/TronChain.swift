// TronChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

public final class TronChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    public typealias Contract = TronContract

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = TRON.Tron.chainId

    public let userReadableName: String = "Tron"

    public var chainTokenInfos: Set<SimpleTokenInfo<TronContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: TronContract!

    public func contract(for address: String) throws -> TronContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: TronContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<TronContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<TronContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<TronContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: TronScan = .init()

    static let trxContractAddress = "TRX"

    public static let `default`: TronChain = .init()

    private init() {
        self.mainContract = TronContract(address: Self.trxContractAddress)
    }
}

public extension CryptoChain where Self == TronChain {
    static var tron: TronChain { .default }
}
