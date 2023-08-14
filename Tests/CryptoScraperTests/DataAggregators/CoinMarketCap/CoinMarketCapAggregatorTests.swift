// CoinMarketCapAggregatorTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSFoundation
import FOSTesting
import XCTest

final class CoinMarketCapAggregatorTests: XCTestCase {
    func testListCoins() async throws {
        let aggregator = CoinMarketCapAggregator()

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
        } catch let e as CoinMarketCapError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            }
        }
    }
}

extension CoinMarketCapAggregator {
    func assertTokenCounts(for contractType: (some CryptoContract).Type, file: StaticString = #filePath, line: UInt = #line) async throws {
        let chainTokens = try await tokens(for: contractType)
        XCTAssertGreaterThan(
            chainTokens.count,
            CoinMarketCapAggregator.expectedMinTokenCount(for: contractType),
            file: file,
            line: line
        )
    }

    static func expectedMinTokenCount(for contractType: (some CryptoContract).Type) -> Int {
        switch contractType {
        case is BitcoinContract.Type: return 1
        case is EthereumContract.Type: return 3200
        case is FantomContract.Type: return 80
        case is BNBContract.Type: return 300
        case is MaticContract.Type: return 250
        case is OptimismContract.Type: return 10
        case is TronContract.Type: return 60
        default:
            fatalError("Unknown token count for contract: \(contractType)")
        }
    }
}
