// BinanceSmartChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class BinanceSmartChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "BNB"

    public var chainTokenInfos: Set<SimpleTokenInfo<BNBContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: BNBContract!

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

    private var tokens: [String: SimpleTokenInfo<BNBContract>]?
    private func loadChainTokens(from newTokens: any Collection<SimpleTokenInfo<BNBContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            // I do not understand why the next line is needed 🤷‍♂️
            let token = token as! SimpleTokenInfo<BNBContract>
            tokens![token.contractAddress.address] = token
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<BNBContract>? {
        tokens?[address]
    }

    public let scanner: BscScan? = .init()

    static let bnbContractAddress = "BNB"

    public static let `default`: BinanceSmartChain = .init()

    private init() {
        self.mainContract = .init(address: Self.bnbContractAddress)
    }
}

public extension CryptoChain where Self == BinanceSmartChain {
    static var binance: BinanceSmartChain { .default }
}
