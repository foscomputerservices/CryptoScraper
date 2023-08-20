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

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: optContract)
        let optAmount = weiAmount.value(units: .ether)

        XCTAssertEqual(optAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(OptimismChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(OptimismContract.self)
    }
}
