// LiveTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import Foundation
import Testing

// Live, opt-in, never in a default `swift test`: CRYPTO_EXCHANGE_LIVE=1 swift test --filter Live
// One read-only public call on Coinbase Advanced Trade, with no key.

@Suite("Live, opt-in: Coinbase", .enabled(if: ProcessInfo.processInfo.environment["CRYPTO_EXCHANGE_LIVE"] == "1"))
struct LiveTests {
    @Test func theBTCUSDBookReadsExactly() async throws {
        let book = try await CoinbaseClient(credential: nil).orderBook(market: try CoinbaseMarketName(validating: "BTC-USD"))
        #expect(book.bestBid < book.bestAsk)
    }
}
