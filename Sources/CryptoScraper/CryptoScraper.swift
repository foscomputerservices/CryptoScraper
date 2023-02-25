// CryptoScraper.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

/// Surfaces an initialization point for the ``CryptoScraper`` library
public enum CryptoScraper {
    private static var defaultAggregator: CryptoDataAggregator {
        CoinGeckoAggregator()
    }

    /// Initializes the block chains
    public static func initialize(dataAggregator: CryptoDataAggregator? = nil) async throws {
        let dataAggregator = dataAggregator ?? defaultAggregator

        try await BlockChains.initializeChains(dataAggregator: dataAggregator)
    }
}
