// FantomContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class FTMContractTests: XCTestCase {
    func testWeiToFTMConversion() throws {
        let ftmChain = FantomChain.default
        let ftmContract = ftmChain.mainContract!

        let weiAmount: UInt128 = 1000000000000000000
        let ftmAmount = ftmContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(ftmAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(FantomChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(FantomContract.self)
    }
}
