// MaticContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct MaticContractTests {
    @Test func testWeiToMaticConversion() throws {
        let polygonChain = PolygonChain.default
        let maticContract = polygonChain.mainContract!

        // Don't specify units as it should default to .wei
        let weiAmount = Amount(quantity: 1000000000000000000, currency: maticContract)
        let maticAmount = weiAmount.value(units: .ether)

        #expect(maticAmount == Double(1.0))
    }

    @Test func testChainToken() {
        #expect(PolygonChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(MaticContract.self)
    }
}
