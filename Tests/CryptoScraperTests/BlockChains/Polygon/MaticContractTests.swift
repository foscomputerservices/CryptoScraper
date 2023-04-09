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

        let weiAmount: UInt128 = 1000000000000000000
        let maticAmount = maticContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(maticAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(PolygonChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(MaticContract.self)
    }
}
