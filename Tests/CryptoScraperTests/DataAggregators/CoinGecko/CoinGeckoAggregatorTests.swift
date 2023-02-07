// CoinGeckoAggregatorTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CoinGeckoAggregatorTests: XCTestCase {
    func testIsAlive() async throws {
        let aggregator = CoinGeckoAggregator()

        let status = await aggregator.isAlive()
        XCTAssertTrue(status)
    }

    func testListCoins() async throws {
        let aggregator = CoinGeckoAggregator()

        do {
            let coins = try await aggregator.listCoins()
            XCTAssertGreaterThan(coins.count, 4500)
        } catch let e as DataFetchError {
            XCTFail(e.localizedDescription)
        } catch let e as CoinGeckoError {
            if e.status.errorCode != 429 { // 429 -- Rate limit exceeded
                XCTFail(e.localizedDescription)
            }
        }
    }
}
