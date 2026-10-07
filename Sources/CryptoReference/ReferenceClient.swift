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

/// An asset as the reference lists it: its symbol, its name, its rank by market capitalization, its tags, the
/// reference's own id, and the chain it is a token on with its instance there
///
/// ```swift
/// assets.first?.rank          // 1
/// assets.first?.tags          // ["mineable", "pow", "layer-1", …]
/// ```
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
    /// The reference's own id for the asset, as text: CoinMarketCap's "28301"
    ///
    /// Two listed assets can share a symbol (two MEME); their ids are distinct, and which is meant is the caller's
    /// to say.
    public let aggregatorId: String
    /// The chain the reference lists the asset as a token on, and its address there, passed up exactly as received;
    /// `nil` for a native coin, and for a row with no `platform` key
    public let platform: Platform?
    /// The asset's instance on that chain: the chain's CAIP-2 id, through the reference's chain names
    /// (``AssetRegistry/chainId(named:by:)``), joined at a colon to the address as the reference gives it, then
    /// validated; built in one place, by the client
    ///
    /// ```swift
    /// usdt.instance?.chainId          // the CAIP-2 id of the chain `usdt.platform` names
    /// rain.platform?.name             // "Arbitrum"
    /// rain.instance                   // nil: the table names no such chain
    /// ```
    ///
    /// `nil` for a native coin, which has no platform, for a platform whose chain the table does not name, and for an
    /// id that does not validate.
    public let instance: AssetInstance?

    /// A chain the reference lists an asset as a token on, in the reference's words
    ///
    /// ```swift
    /// usdt.platform?.name             // "Ethereum"
    /// usdt.platform?.tokenAddress     // the token's contract address, as the reference wrote it
    /// ```
    public struct Platform: Codable, Hashable, Sendable {
        /// The reference's name for the chain: CoinMarketCap's "BNB Smart Chain (BEP20)"
        public let name: String
        /// The token's address on that chain, verbatim
        public let tokenAddress: String

        public init(name: String, tokenAddress: String) {
            self.name = name
            self.tokenAddress = tokenAddress
        }
    }

    public init(
        symbol: AssetSymbol,
        name: String,
        rank: Int,
        tags: [String],
        isCountedInMarketCap: Bool,
        aggregatorId: String,
        platform: Platform?,
        instance: AssetInstance?
    ) {
        self.symbol = symbol
        self.name = name
        self.rank = rank
        self.tags = tags
        self.isCountedInMarketCap = isCountedInMarketCap
        self.aggregatorId = aggregatorId
        self.platform = platform
        self.instance = instance
    }
}

extension ReferenceClientAsset {
    public static func stub() -> Self { .stub(rank: 42) }

    /// FRED, "Fred Flintstone", rank 42, the tag "bedrock", counted, the reference's id "42", a native: no platform
    /// and no instance
    ///
    /// ```swift
    /// let uncounted = ReferenceClientAsset.stub(isCountedInMarketCap: false)
    /// ```
    public static func stub(
        symbol: AssetSymbol = .stub(),
        name: String = "Fred Flintstone",
        rank: Int = 42,
        tags: [String] = ["bedrock"],
        isCountedInMarketCap: Bool = true,
        aggregatorId: String = "42",
        platform: Platform? = nil,
        instance: AssetInstance? = nil
    ) -> Self {
        .init(
            symbol: symbol,
            name: name,
            rank: rank,
            tags: tags,
            isCountedInMarketCap: isCountedInMarketCap,
            aggregatorId: aggregatorId,
            platform: platform,
            instance: instance
        )
    }
}

extension ReferenceClientAsset.Platform: Stubbable {
    public static func stub() -> Self { .stub(name: "Bedrock") }

    /// The chain "Bedrock", the address "quarry-42": a name no reference table holds
    public static func stub(name: String = "Bedrock", tokenAddress: String = "quarry-42") -> Self {
        .init(name: name, tokenAddress: tokenAddress)
    }
}
