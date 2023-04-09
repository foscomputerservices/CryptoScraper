// CryptoScraperTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CryptoScraperTests: XCTestCase {
    func testInitialization() async throws {
        do {
            _ = try await CryptoScraper.initialize()
        } catch let e as CoinGeckoError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
                return
            }
        } catch let e as BlockChainError {
            if e != BlockChainError.alreadyInitialized {
                XCTFail(e.localizedDescription)
                return
            }
        }

        XCTAssertGreaterThan(EthereumChain.default.chainTokenInfos.count, 4000)
        XCTAssertGreaterThan(FantomChain.default.chainTokenInfos.count, 300)
    }
}
