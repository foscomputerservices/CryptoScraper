// BlockChainsTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import XCTest

final class BlockChainsTests: XCTestCase {
    func testInitialize_CoinGecko() async throws {
        do {
            try await BlockChains.initializeChains(dataAggregator: CoinGeckoAggregator())

            XCTAssertEqual(BitcoinChain.default.chainCryptos.count, 1)
            XCTAssertGreaterThan(EthereumChain.default.chainCryptos.count, 4500)
            XCTAssertGreaterThan(FantomChain.default.chainCryptos.count, 300)
            XCTAssertGreaterThan(BinanceSmartChain.default.chainCryptos.count, 3000)
            XCTAssertGreaterThan(PolygonChain.default.chainCryptos.count, 900)
            XCTAssertGreaterThan(OptimismChain.default.chainCryptos.count, 80)
        } catch let e as CoinGeckoError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("******************************************")
                print("*** Unable to test, rate-limit reached ***")
                print("******************************************")
            }
        }
    }

    func testInitialize_CoinMarketCap() async throws {
        do {
            try await BlockChains.initializeChains(dataAggregator: CoinMarketCapAggregator())

            XCTAssertEqual(BitcoinChain.default.chainCryptos.count, 1)
            XCTAssertGreaterThan(EthereumChain.default.chainCryptos.count, 3200)
            XCTAssertGreaterThan(FantomChain.default.chainCryptos.count, 90)
            XCTAssertGreaterThan(BinanceSmartChain.default.chainCryptos.count, 2800)
            XCTAssertGreaterThan(PolygonChain.default.chainCryptos.count, 200)
            XCTAssertGreaterThan(OptimismChain.default.chainCryptos.count, 10)
        } catch let e as CoinMarketCapError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("******************************************")
                print("*** Unable to test, rate-limit reached ***")
                print("******************************************")
            }
        }
    }
}
