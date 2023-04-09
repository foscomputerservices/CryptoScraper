// EthereumContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class EthereumContractTests: XCTestCase {
    func testWeiToETHConversion() throws {
        let ethChain = EthereumChain.default
        let ethContract = ethChain.mainContract!

        let weiAmount: UInt128 = 1000000000000000000
        let ethAmount = ethContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(ethAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(EthereumChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(EthereumContract.self)
    }
}
