// CryptoScraper.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Synchronization

/// Surfaces an initialization point for the ``CryptoScraper`` library
public enum CryptoScraper {
    private static var defaultAggregator: CryptoDataAggregator {
        CoinGeckoAggregator()
    }

    // Checked and set in one step under the lock, so two concurrent first calls cannot both proceed.
    private static let initialized = Mutex<Bool>(false)

    /// Initializes the block chains
    ///
    /// This method may be called multiple times, but does nothing after the 1st call. The check is atomic, but a later call returns at once, without waiting for the 1st call to finish loading.
    ///
    /// - Note: The default ``CryptoDataAggregator`` is ``CoinGeckoAggregator``
    public static func initialize(dataAggregator: CryptoDataAggregator? = nil) async throws {
        let alreadyInitialized = initialized.withLock { initialized in
            defer { initialized = true }
            return initialized
        }
        guard !alreadyInitialized else { return }

        let dataAggregator = dataAggregator ?? defaultAggregator

        try await BlockChains.initializeChains(dataAggregator: dataAggregator)
    }
}
