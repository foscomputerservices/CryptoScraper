// TronContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct TRXContractTests {
    @Test func testSUNToTRXConversion() throws {
        let tronChain = TronChain.default
        let tronContract = tronChain.mainContract!

        // Don't specify units as it should default to .sun
        let weiAmount = Amount(quantity: 1000000, currency: tronContract)
        let trxAmount = weiAmount.value(units: .trx)

        #expect(trxAmount == Double(1.0))
    }

    @Test func testChainToken() {
        #expect(TronChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(TronContract.self)
    }
}
