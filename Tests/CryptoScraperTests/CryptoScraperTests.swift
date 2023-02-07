// CryptoScraperTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CryptoScraperTests: XCTestCase {
    func testInitialization() async throws {
        try await CryptoScraper.initialize()

        XCTAssertGreaterThan(EthereumChain.default.chainCryptos.count, 4500)
    }
}
