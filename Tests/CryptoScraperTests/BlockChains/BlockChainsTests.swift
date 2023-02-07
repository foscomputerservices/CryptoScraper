// BlockChainsTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import XCTest

final class BlockChainsTests: XCTestCase {
    func testInitialize_CoinGecko() async throws {
        try await BlockChains.initializeChains(dataAggregator: CoinGeckoAggregator())

        XCTAssertGreaterThan(EthereumChain.default.chainCryptos.count, 4500)
        XCTAssertGreaterThan(FantomChain.default.chainCryptos.count, 300)
    }
}
