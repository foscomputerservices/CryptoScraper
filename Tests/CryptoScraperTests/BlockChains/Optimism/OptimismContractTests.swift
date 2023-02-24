// EthereumContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class OptimismContractTests: XCTestCase {
    func testWeiToETHConversion() throws {
        let optChain = OptimismChain.default
        let optContract = optChain.mainContract as! OptimismContract

        let weiAmount: UInt128 = 1000000000000000000
        let optAmount = optContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(optAmount, Double(1.0))
    }
}
