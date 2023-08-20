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

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: ethContract)
        let ethAmount = weiAmount.value(units: .ether)

        XCTAssertEqual(ethAmount, Double(1.0))
    }

    func testChainToken() {
        XCTAssertTrue(EthereumChain.default.mainContract!.isChainToken)
    }

    func testCodable() throws {
        try FOSAssertCodable(EthereumContract.self)
    }
}
