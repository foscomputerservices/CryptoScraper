// TronContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class TRXContractTests: XCTestCase {
    func testWeiToTRXConversion() throws {
        let tronChain = TronChain.default
        let tronContract = tronChain.mainContract!

        let weiAmount: UInt128 = 1000000000000000000
        let trxAmount = tronContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(trxAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(TronChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(TronContract.self)
    }
}
