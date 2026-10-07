// AssetReferenceSource.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A reference source that names a chain in its own words: CoinGecko or CoinMarketCap
///
/// ```swift
/// try AssetRegistry.chainId(named: "polygon-pos", by: .coinGecko)      // "eip155:137"
/// ```
public enum AssetReferenceSource: Codable, Hashable, Sendable, Stubbable {
    case coinGecko
    case coinMarketCap
}

// MARK: Stubs

extension AssetReferenceSource {
    public static func stub() -> Self { .coinMarketCap }
}
