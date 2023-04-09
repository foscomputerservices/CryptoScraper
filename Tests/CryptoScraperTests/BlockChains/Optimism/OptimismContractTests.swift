// OptimismContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class OptimismContractTests: XCTestCase {
    func testWeiToETHConversion() throws {
        let optChain = OptimismChain.default
        let optContract = optChain.mainContract!

        let weiAmount: UInt128 = 1000000000000000000
        let optAmount = optContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(optAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(OptimismChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(OptimismContract.self)
    }
}
