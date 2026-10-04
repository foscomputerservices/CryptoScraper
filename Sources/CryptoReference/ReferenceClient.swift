// ReferenceClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// The public contract of a reference client: what a market-data reference lists for an asset, fresh on
/// FOSFoundation's fetch pattern
///
/// ```swift
/// let assets = try await client.reference(symbols: [btc, eth])
/// ```
public protocol ReferenceClient: Sendable {
    func reference(symbols: [AssetSymbol]) async throws -> [ReferenceClientAsset]
}

/// An asset as the reference lists it: its symbol, its name, its rank by market capitalization and its tags
///
/// ```swift
/// assets.first?.rank          // 1
/// assets.first?.tags          // ["mineable", "pow", "layer-1", …]
/// ```
///
/// - Note: UNRATIFIED: C33 declares sector and tier; this value hands up rank and tags, the reading is the caller's (L17).
///
/// The reference lists no sector and no tier. The sector, a named set of tags with an "other", and the tier, a named
/// band of the rank, are readings, and a public client hands up facts and decides nothing.
public struct ReferenceClientAsset: Codable, Hashable, Sendable, Stubbable {
    public let symbol: AssetSymbol
    /// The asset's name as the reference writes it: "Bitcoin"
    public let name: String
    /// The asset's place in the reference's ranking by market capitalization, 1 the largest
    public let rank: Int
    /// The reference's own category tags, verbatim, in the reference's order
    public let tags: [String]
    /// Whether the reference counts the asset in its total market capitalization; most wrapped and pegged tokens it
    /// does not
    public let isCountedInMarketCap: Bool

    public init(symbol: AssetSymbol, name: String, rank: Int, tags: [String], isCountedInMarketCap: Bool) {
        self.symbol = symbol
        self.name = name
        self.rank = rank
        self.tags = tags
        self.isCountedInMarketCap = isCountedInMarketCap
    }
}

extension ReferenceClientAsset {
    public static func stub() -> Self { .stub(rank: 42) }

    /// FRED, "Fred Flintstone", rank 42, the tag "bedrock", counted
    ///
    /// ```swift
    /// let uncounted = ReferenceClientAsset.stub(isCountedInMarketCap: false)
    /// ```
    public static func stub(
        symbol: AssetSymbol = .stub(),
        name: String = "Fred Flintstone",
        rank: Int = 42,
        tags: [String] = ["bedrock"],
        isCountedInMarketCap: Bool = true
    ) -> Self {
        .init(symbol: symbol, name: name, rank: rank, tags: tags, isCountedInMarketCap: isCountedInMarketCap)
    }
}
