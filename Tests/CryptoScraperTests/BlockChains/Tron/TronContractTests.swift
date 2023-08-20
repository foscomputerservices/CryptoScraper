// TronContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class TRXContractTests: XCTestCase {
    func testSUNToTRXConversion() throws {
        let tronChain = TronChain.default
        let tronContract = tronChain.mainContract!

        // Don't specify units as it should default to .sun
        let weiAmount = Amount(quantity: 1000000, currency: tronContract)
        let trxAmount = weiAmount.value(units: .trx)

        XCTAssertEqual(trxAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(TronChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(TronContract.self)
    }
}
