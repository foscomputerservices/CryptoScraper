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

            XCTAssertEqual(
                BitcoinChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: BitcoinContract.self)
            )
            XCTAssertGreaterThan(
                EthereumChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: EthereumContract.self)
            )
            XCTAssertGreaterThan(
                EthereumChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: EthereumContract.self)
            )
            XCTAssertGreaterThan(
                FantomChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: FantomContract.self)
            )
            XCTAssertGreaterThan(
                BinanceSmartChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: BNBContract.self)
            )
            XCTAssertGreaterThan(
                PolygonChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: MaticContract.self)
            )
            XCTAssertGreaterThan(
                OptimismChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: OptimismContract.self)
            )
            XCTAssertGreaterThan(
                TronChain.default.chainTokenInfos.count,
                CoinGeckoAggregator.expectedMinTokenCount(for: TronContract.self)
            )
        } catch let e as CoinGeckoError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("*************************************************")
                print("*** Error: Unable to test, rate-limit reached ***")
                print("*************************************************")
            }
        }
    }

    func testInitialize_CoinMarketCap() async throws {
        do {
            try await BlockChains.initializeChains(dataAggregator: CoinMarketCapAggregator())

            XCTAssertEqual(BitcoinChain.default.chainTokenInfos.count, 1)
            XCTAssertGreaterThan(EthereumChain.default.chainTokenInfos.count, 3200)
            XCTAssertGreaterThan(FantomChain.default.chainTokenInfos.count, 90)
            XCTAssertGreaterThan(BinanceSmartChain.default.chainTokenInfos.count, 2800)
            XCTAssertGreaterThan(PolygonChain.default.chainTokenInfos.count, 200)
            XCTAssertGreaterThan(OptimismChain.default.chainTokenInfos.count, 10)
            XCTAssertGreaterThan(TronChain.default.chainTokenInfos.count, 80)
        } catch let e as CoinMarketCapError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("*************************************************")
                print("*** Error: Unable to test, rate-limit reached ***")
                print("*************************************************")
            }
        } catch let e as BlockChainError {
            if e != BlockChainError.alreadyInitialized {
                XCTFail(e.localizedDescription)
            }
        }
    }
}
