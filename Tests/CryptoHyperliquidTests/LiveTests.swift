// LiveTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import Foundation
import Testing

// Live, opt-in, never in a default `swift test`: CRYPTO_EXCHANGE_LIVE=1 swift test --filter Live
// One read-only call on Hyperliquid's test market, with no key.

@Suite("Live, opt-in: Hyperliquid's test market", .enabled(if: ProcessInfo.processInfo.environment["CRYPTO_EXCHANGE_LIVE"] == "1"))
struct LiveTests {
    @Test func theTestMarketsBTCBookReadsExactly() async throws {
        let client = HyperliquidClient(credential: nil, endpoint: .testMarket)
        let book = try await client.orderBook(market: try HyperliquidMarketName(validating: "BTC"))
        #expect(book.bestBid < book.bestAsk)
    }
}
