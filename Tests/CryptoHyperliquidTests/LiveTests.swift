// LiveTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import Foundation
import Testing

// Live, opt-in, never in a default `swift test`: CRYPTO_EXCHANGE_LIVE=1 swift test --filter Live
// Read-only calls on Hyperliquid's public endpoints, with no key.

@Suite("Live, opt-in: Hyperliquid's test market", .enabled(if: ProcessInfo.processInfo.environment["CRYPTO_EXCHANGE_LIVE"] == "1"))
struct LiveTests {
    @Test func theTestMarketsBTCBookReadsExactly() async throws {
        let client = HyperliquidClient(credential: nil, endpoint: .testMarket)
        let book = try await client.orderBook(market: try HyperliquidMarketName(validating: "BTC"))
        #expect(book.bestBid < book.bestAsk)
    }

    // Added 2026-10-09: on both networks the listed markets carry DOGE, SAND, NEO, RUNE and ALGO as their declared
    // holdings (the units check passing at the declared decimals), and list neither COTI nor NMR.
    @Test(arguments: [HyperliquidEndpoint.testMarket, .production])
    func bothNetworksListTheFiveDeclaredAndNeitherCOTINorNMR(endpoint: HyperliquidEndpoint) async throws {
        let markets = try await HyperliquidClient(credential: nil, endpoint: endpoint).markets()
        for holding in [HyperliquidHolding.doge, .sand, .neo, .rune, .algo] {
            let market = try #require(markets.first { $0.name.text == holding.wireName })
            #expect(market.base == AssetInstance(holding))
        }
        #expect(!markets.contains { ["COTI", "NMR"].contains($0.name.text) })
    }
}
