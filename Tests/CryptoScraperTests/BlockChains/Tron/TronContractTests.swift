// TronContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class TRXContractTests: XCTestCase {
    func testWeiToTRXConversion() throws {
        let tronChain = FantomChain.default
        let tronContract = tronChain.mainContract as! FantomContract

        let weiAmount: UInt128 = 1000000000000000000
        let trxAmount = tronContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(trxAmount, Double(1.0))
    }
}
