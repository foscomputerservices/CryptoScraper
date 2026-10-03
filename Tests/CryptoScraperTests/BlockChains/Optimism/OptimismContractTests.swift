// OptimismContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct OptimismContractTests {
    @Test func testWeiToETHConversion() throws {
        let optChain = OptimismChain.default
        let optContract = optChain.mainContract!

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: optContract)
        let optAmount = weiAmount.value(units: .ether)

        #expect(optAmount == Double(1.0))
    }

    @Test func testChainToken() {
        #expect(OptimismChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(OptimismContract.self)
    }
}
