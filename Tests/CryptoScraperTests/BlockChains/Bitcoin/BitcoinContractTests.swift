// BitcoinContractTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct BitcoinContractTests {
    @Test func testSatoshiToSatoshiConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: Int128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .satoshi)

        #expect(btcAmount == Double(satAmount))
    }

    @Test func testSatoshiToBTCConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: Int128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .btc)

        #expect(btcAmount == Double(1.0))
    }

    @Test func testSatoshiToDefaultDisplayUnitsConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let satAmount: Int128 = 100000000
        let btcAmount = btcContract.value(of: satAmount, in: .defaultDisplayUnits)

        #expect(btcAmount == Double(1.0))
    }

    @Test func testBTCToSatoshiConversion() throws {
        let btcChain = BitcoinChain.default
        let btcContract = btcChain.mainContract!

        let btcAmount = 1.0
        let satAmount = btcContract.baseUnitsValue(of: btcAmount, in: .btc)

        #expect(satAmount == 100000000)
    }

    @Test func testChainToken() {
        #expect(BitcoinChain.default.mainContract!.isChainToken)
    }

    @Test func testCodable() throws {
        try expectCodable(BitcoinContract.self)
    }
}
