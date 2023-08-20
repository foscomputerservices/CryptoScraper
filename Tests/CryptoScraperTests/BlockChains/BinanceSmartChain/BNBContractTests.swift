// BNBContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class BNBContractTests: XCTestCase {
    // TODO: Restore when we figure out display
//    func testWeiToBNBConversion() throws {
//        let bnbChain = BinanceSmartChain.default
//        let bnbContract = bnbChain.mainContract!
//
//        let weiAmount: UInt128 = 1000000000000000000
//        let bnbAmount = bnbContract.displayAmount(amount: weiAmount, inUnits: .ether)
//
//        XCTAssertEqual(bnbAmount, Double(1.0))
//    }

    func testChainToken() {
        XCTAssertTrue(BinanceSmartChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(BNBContract.self)
    }
}
