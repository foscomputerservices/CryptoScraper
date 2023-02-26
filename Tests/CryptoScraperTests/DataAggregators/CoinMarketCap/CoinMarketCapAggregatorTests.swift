// CoinMarketCapAggregatorTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CoinMarketCapAggregatorTests: XCTestCase {
    func testListCoins() async throws {
        let aggregator = CoinMarketCapAggregator()

        do {
            let coins = try await aggregator.listCoins()
            XCTAssertGreaterThan(coins.count, 6200)
        } catch let e as DataFetchError {
            XCTFail(e.localizedDescription)
        } catch let e as CoinMarketCapError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            }
        }
    }
}
