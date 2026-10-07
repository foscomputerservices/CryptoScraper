// BinanceSmartChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

public final class BinanceSmartChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = EIP155.BinanceSmartChain.chainId

    public let userReadableName: String = "BNB"

    public var chainTokenInfos: Set<SimpleTokenInfo<BNBContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: BNBContract!

    public func contract(for address: String) throws -> BNBContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: BNBContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<BNBContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<BNBContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<BNBContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: BscScan = .init()

    static let bnbContractAddress = "bnb"

    public static let `default`: BinanceSmartChain = .init()

    private init() {
        self.mainContract = .init(address: Self.bnbContractAddress)
    }
}

public extension CryptoChain where Self == BinanceSmartChain {
    static var binance: BinanceSmartChain { .default }
}
