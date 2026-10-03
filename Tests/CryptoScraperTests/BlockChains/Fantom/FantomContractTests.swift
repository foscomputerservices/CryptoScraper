// FantomContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct FTMContractTests {
    // TODO: Restore when we figure out display
//    func testWeiToFTMConversion() throws {
//        let ftmChain = FantomChain.default
//        let ftmContract = ftmChain.mainContract!
//
//        let weiAmount: UInt128 = 1000000000000000000
//        let ftmAmount = ftmContract.displayAmount(amount: weiAmount, inUnits: .ether)
//
//        XCTAssertEqual(ftmAmount, Double(1.0))
//    }

    @Test func testChainToken() {
        #expect(FantomChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(FantomContract.self)
    }
}
