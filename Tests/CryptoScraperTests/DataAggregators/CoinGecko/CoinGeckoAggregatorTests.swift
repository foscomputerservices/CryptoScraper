// CoinGeckoAggregatorTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSFoundation
import XCTest

final class CoinGeckoAggregatorTests: XCTestCase {
    func testIsAlive() async throws {
        let aggregator = CoinGeckoAggregator()

        let status = await aggregator.isAlive()
        XCTAssertTrue(status)
    }

    func testListTokens() async throws {
        let aggregator = CoinGeckoAggregator()

        do {
            // At this time, the aggregator isn't providing base-chain
            // tokens (e.g. BTC, ETH, FTM, etc.) so the count from the
            // aggregator is 1 less than we might expect
//            try await aggregator.assertTokenCounts(for: BitcoinContract.self)
            try await aggregator.assertTokenCounts(for: EthereumContract.self)
            try await aggregator.assertTokenCounts(for: FantomContract.self)
            try await aggregator.assertTokenCounts(for: BNBContract.self)
            try await aggregator.assertTokenCounts(for: MaticContract.self)
            try await aggregator.assertTokenCounts(for: OptimismContract.self)
            try await aggregator.assertTokenCounts(for: TronContract.self)
        } catch let e as DataFetchError {
            XCTFail(e.localizedDescription)
        } catch let e as CoinGeckoError {
            if e.rateLimitReached {
                print("*** Unable to test, rate-limit reached.")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
}

extension CoinGeckoAggregator {
    func assertTokenCounts(for contractType: (some CryptoContract).Type, file: StaticString = #filePath, line: UInt = #line) async throws {
        let chainTokens = try await tokens(for: contractType)
        XCTAssertGreaterThan(
            chainTokens.count,
            CoinGeckoAggregator.expectedMinTokenCount(for: contractType),
            file: file,
            line: line
        )
    }

    static func expectedMinTokenCount(for contractType: (some CryptoContract).Type) -> Int {
        switch contractType {
        case is BitcoinContract.Type: return 1
        case is EthereumContract.Type: return 4000
        case is FantomContract.Type: return 250
        case is BNBContract.Type: return 300
        case is MaticContract.Type: return 900
        case is OptimismContract.Type: return 80
        case is TronContract.Type: return 93
        default:
            fatalError("Unknown token count for contract: \(contractType)")
        }
    }
}
