// CryptoChainTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CryptoChainTests: XCTestCase {
    func testIsSame() {
        let bitcoinChain = BitcoinChain.default
        let ethereumChain = EthereumChain.default

        XCTAssertTrue(bitcoinChain.isSame(as: bitcoinChain))
        XCTAssertFalse(bitcoinChain.isSame(as: ethereumChain))
    }
}
