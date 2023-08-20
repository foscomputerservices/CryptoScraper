// BitcoinContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class BitcoinContractTests: XCTestCase {
    func testSatoshiToSatoshiConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: UInt128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .satoshi)

        XCTAssertEqual(btcAmount, Double(satAmount))
    }

    func testSatoshiToBTCConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: UInt128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .btc)

        XCTAssertEqual(btcAmount, Double(1.0))
    }

    func testSatoshiToDefaultDisplayUnitsConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: UInt128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .defaultDisplayUnits)

        XCTAssertEqual(btcAmount, Double(1.0))
    }

    func testBTCToSatoshiConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let btcAmount = 1.0
        let satAmount = btcContract.baseUnitsValue(of: btcAmount, in: .btc)

        XCTAssertEqual(satAmount, 100000000)
    }

    func testChainToken() {
        XCTAssertTrue(BitcoinChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(BitcoinContract.self)
    }
}
