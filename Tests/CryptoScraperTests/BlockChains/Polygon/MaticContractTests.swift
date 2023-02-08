// MaticContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class MaticContractTests: XCTestCase {
    func testWeiToMaticConversion() throws {
        let polygonChain = PolygonChain.default
        let maticContract = polygonChain.mainContract as! MaticContract

        let weiAmount: UInt128 = 1000000000000000000
        let maticAmount = maticContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(maticAmount, Double(1.0))
    }
}
