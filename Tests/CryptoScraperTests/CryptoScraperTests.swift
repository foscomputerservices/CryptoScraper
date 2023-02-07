// CryptoScraperTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CryptoScraperTests: XCTestCase {
    func testInitialization() async throws {
        do {
            try await CryptoScraper.initialize()

            XCTAssertGreaterThan(EthereumChain.default.chainCryptos.count, 4500)
            XCTAssertGreaterThan(FantomChain.default.chainCryptos.count, 300)
        } catch let e as CoinGeckoError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            }
        }
    }
}
