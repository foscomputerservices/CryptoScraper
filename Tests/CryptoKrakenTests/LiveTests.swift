// LiveTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoKraken
import CryptoOHLCV
import Foundation
import Testing

// Live, opt-in, never in a default `swift test`: CRYPTO_EXCHANGE_LIVE=1 swift test --filter Live
// One read-only public call on Kraken, with no key.

@Suite("Live, opt-in: Kraken", .enabled(if: ProcessInfo.processInfo.environment["CRYPTO_EXCHANGE_LIVE"] == "1"))
struct LiveTests {
    @Test func theXBTUSDBookReadsExactly() async throws {
        let book = try await KrakenClient(credential: nil).orderBook(market: try KrakenMarketName(validating: "XBTUSD"))
        #expect(book.bestBid < book.bestAsk)
    }
}
