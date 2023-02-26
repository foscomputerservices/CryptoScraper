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
    ///
    /// - Note: The default ``CryptoDataAggregator`` is ``CoinGeckoAggregator``
    public static func initialize(dataAggregator: CryptoDataAggregator? = nil) async throws {
        let dataAggregator = dataAggregator ?? defaultAggregator

        try await BlockChains.initializeChains(dataAggregator: dataAggregator)
    }
}
