// BNBContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class BNBContractTests: XCTestCase {
    func testWeiToBNBConversion() throws {
        let bnbChain = BinanceSmartChain.default
        let bnbContract = bnbChain.mainContract as! BNBContract

        let weiAmount: UInt128 = 1000000000000000000
        let bnbAmount = bnbContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(bnbAmount, Double(1.0))
    }
}
