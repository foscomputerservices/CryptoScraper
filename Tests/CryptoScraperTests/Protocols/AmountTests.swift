// AmountTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import Testing

@Suite struct AmountTests {
    @Test func testChainBaseUnitInit() {
        let satAmount: Swift.Int128 = 100000000
        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        #expect(amount.quantity == satAmount)
    }

    @Test func testChainAlternateUnitInit() {
        let btcAmount = 1.0
        let amount = Amount(
            quantity: btcAmount,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        #expect(amount.quantity == 100000000)
    }

    @Test func testEquality1() {
        let amount1 = Amount(
            quantity: 100000000,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        #expect(amount1 == amount2)
    }

    @Test func testEquality2() {
        let amount1 = Amount(
            quantity: 1,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        #expect(amount1 != amount2)
    }

    @Test func testComparable() {
        let amount1 = Amount(
            quantity: 1,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        #expect(amount1 < amount2)
        #expect(amount1 <= amount1)
        #expect(amount2 > amount1)
        #expect(amount1 >= amount1)
    }

    @Test func testValue() {
        let satAmount: Swift.Int128 = 100000000
        let btcAmount = 1.0

        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        #expect(amount.value(units: .satoshi) == Double(satAmount))
        #expect(amount.value(units: .btc) == btcAmount)
    }

    @Test func testDisplay() {
        let satAmount: Swift.Int128 = 100000000

        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        #expect(amount.display(units: .satoshi) == "SAT 100,000,000")
        #expect(amount.display() == "BTC 1.00000000")
    }

    @Test func testwBTCUnits() {
        let wBTCContract = EthereumContract(address: "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599")
        let btcAmountDecimal: Double = 0.1
        let btcAmount = Amount(quantity: btcAmountDecimal, currency: wBTCContract, units: .defaultDisplayUnits)

        #expect(btcAmount.value(units: .defaultDisplayUnits) == 0.1)
    }

    @Test func testCodable() throws {
        try expectCodable(Amount<USD>.self)
    }
}
