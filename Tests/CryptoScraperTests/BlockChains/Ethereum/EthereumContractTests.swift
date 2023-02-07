// EthereumContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class EtherContractTests: XCTestCase {
    func testWeiToETHConversion() throws {
        let ethChain = EthereumChain()
        let ethContract = ethChain.mainContract as! EthereumContract

        let weiAmount: Int64 = 1000000000000000000
        let ethAmount = ethContract.displayAmount(amount: weiAmount, inUnits: .ether)

        XCTAssertEqual(ethAmount, Double(1.0))
    }
}
