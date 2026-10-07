// CoinGeckoKeyNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import Foundation
import Testing

/// The key defect found in step 8a: with a key set, the aggregator asked the pro endpoint and sent no key. CoinGecko's
/// authentication documentation: the pro endpoint takes the key in the header `x-cg-pro-api-key`. No network; the key
/// is set through the aggregator's own static, never the environment, and cleared after.
@Suite(.serialized) struct CoinGeckoKeyNoNetworkTests {
    @Test func aSetKeyIsSentInTheProHeaderToTheProEndpoint() throws {
        CoinGeckoAggregator.apiKey = "fred-not-a-key"
        defer { CoinGeckoAggregator.apiKey = nil }

        let headers = try #require(CoinGeckoAggregator.headers())
        #expect(headers.map(\.field) == ["x-cg-pro-api-key"])
        #expect(headers.map(\.value) == ["fred-not-a-key"])
        #expect(CoinGeckoAggregator.endPoint.absoluteString == "https://pro-api.coingecko.com/api/v3")
    }

    @Test func noKeyIsNoHeaderAndTheFreeEndpoint() {
        // Where the process's environment holds a key, the aggregator reads it; this half then has nothing to say.
        guard ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] == nil else { return }
        CoinGeckoAggregator.apiKey = nil

        #expect(CoinGeckoAggregator.headers() == nil)
        #expect(CoinGeckoAggregator.endPoint.absoluteString == "https://api.coingecko.com/api/v3")
    }
}
