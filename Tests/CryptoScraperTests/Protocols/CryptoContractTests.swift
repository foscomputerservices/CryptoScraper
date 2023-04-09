// CryptoContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class CryptoContractTests: XCTestCase {
    func testIsSame() {
        let bitcoinContract = BitcoinChain.default.mainContract!
        let ethereumContract = EthereumChain.default.mainContract!

        XCTAssertTrue(bitcoinContract.isSame(as: bitcoinContract))
        XCTAssertFalse(bitcoinContract.isSame(as: ethereumContract))
    }
}
