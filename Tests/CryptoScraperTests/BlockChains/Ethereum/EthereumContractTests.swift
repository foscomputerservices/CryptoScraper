// EthereumContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct EthereumContractTests {
    @Test func testWeiToETHConversion() throws {
        let ethChain = EthereumChain.default
        let ethContract = ethChain.mainContract!

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: ethContract)
        let ethAmount = weiAmount.value(units: .ether)

        #expect(ethAmount == Double(1.0))
    }

    @Test func testChainToken() {
        #expect(EthereumChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(EthereumContract.self)
    }
}
