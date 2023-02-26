// CryptoDataAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoDataAggregator`` provides standardized meta-data information
/// for coins across all block chains
public protocol CryptoDataAggregator {
    /// Returns the coins known to the aggregator
    func listCoins() async throws -> [CryptoInfo]
}
