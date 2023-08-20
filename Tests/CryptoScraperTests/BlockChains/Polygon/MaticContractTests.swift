// MaticContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class MaticContractTests: XCTestCase {
    func testWeiToMaticConversion() throws {
        let polygonChain = PolygonChain.default
        let maticContract = polygonChain.mainContract!

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: maticContract)
        let maticAmount = weiAmount.value(units: .ether)

        XCTAssertEqual(maticAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(PolygonChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(MaticContract.self)
    }
}
