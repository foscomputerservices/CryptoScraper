// BlockChains.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

enum BlockChains {
    private static var initialized: Bool = false

    /// Initializes all of the supported block chains
    static func initializeChains(dataAggregator: CryptoDataAggregator) async throws {
        guard !initialized else { return }

        let coins = try await dataAggregator.listCoins()

        EthereumChain.default.loadChainCryptos(from: coins)

        initialized = true
    }
}