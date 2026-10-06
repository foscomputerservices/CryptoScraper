// CryptoDataAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A ``CryptoDataAggregator`` provides standardized meta-data information
/// for coins across all block chains
public protocol CryptoDataAggregator {
    /// Returns the known tokens for a given ``CryptoContract`` type
    func tokens<Contract: CryptoContract & Sendable>(for contract: Contract.Type) async throws -> Set<SimpleTokenInfo<Contract>>
}
