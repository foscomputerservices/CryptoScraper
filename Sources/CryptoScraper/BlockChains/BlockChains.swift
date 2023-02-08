// BlockChains.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

enum BlockChains {
    private static var initialized: Bool = false

    /// Initializes all of the supported block chains
    ///
    /// All supported block chains are initialized and loaded with the crypto coin specifications
    /// that are known to the provided ``CryptoDataAggregator``
    static func initializeChains(dataAggregator: CryptoDataAggregator) async throws {
        guard !initialized else { return }

        let coins = try await dataAggregator.listCoins()

        EthereumChain.default.loadChainCryptos(from: coins)
        FantomChain.default.loadChainCryptos(from: coins)
        BinanceSmartChain.default.loadChainCryptos(from: coins)

        initialized = true
    }
}
