// BitcoinContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class BitcoinContractTests: XCTestCase {
    func testSatoshiToBTCConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract as! BitcoinContract

        let satAmount: UInt128 = 100000000
        let btcAmount = btcContract.displayAmount(amount: satAmount, inUnits: .btc)

        XCTAssertEqual(btcAmount, Double(1.0))
    }
}
