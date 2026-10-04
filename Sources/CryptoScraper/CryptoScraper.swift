// CryptoScraper.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

/// Surfaces an initialization point for the ``CryptoScraper`` library
public enum CryptoScraper {
    private static var defaultAggregator: CryptoDataAggregator {
        CoinGeckoAggregator()
    }

    private static var initialized = false

    /// Initializes the block chains
    ///
    /// This method may be called multiple times, but does nothing after the 1st call. It is **not** thread-safe.
    ///
    /// - Note: The default ``CryptoDataAggregator`` is ``CoinGeckoAggregator``
    public static func initialize(dataAggregator: CryptoDataAggregator? = nil) async throws {
        guard !initialized else { return }
        initialized = true

        let dataAggregator = dataAggregator ?? defaultAggregator

        try await BlockChains.initializeChains(dataAggregator: dataAggregator)
    }
}
