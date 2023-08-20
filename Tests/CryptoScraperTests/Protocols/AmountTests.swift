// AmountTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class AmountTests: XCTestCase {
    func testChainBaseUnitInit() {
        let satAmount: UInt128 = 100000000
        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        XCTAssertEqual(amount.quantity, satAmount)
    }

    func testChainAlternateUnitInit() {
        let btcAmount = 1.0
        let amount = Amount(
            quantity: btcAmount,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        XCTAssertEqual(amount.quantity, 100000000)
    }

    func testEquality1() {
        let amount1 = Amount(
            quantity: 100000000,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        XCTAssertEqual(amount1, amount2)
    }

    func testEquality2() {
        let amount1 = Amount(
            quantity: 1,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        XCTAssertNotEqual(amount1, amount2)
    }

    func testComparable() {
        let amount1 = Amount(
            quantity: 1,
            currency: BitcoinChain.default.mainContract
        )

        let amount2 = Amount(
            quantity: 1.0,
            currency: BitcoinChain.default.mainContract,
            units: .btc
        )

        XCTAssertLessThan(amount1, amount2)
        XCTAssertLessThanOrEqual(amount1, amount1)
        XCTAssertGreaterThan(amount2, amount1)
        XCTAssertGreaterThanOrEqual(amount1, amount1)
    }

    func testValue() {
        let satAmount: UInt128 = 100000000
        let btcAmount = 1.0

        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        XCTAssertEqual(amount.value(units: .satoshi), Double(satAmount))
        XCTAssertEqual(amount.value(units: .btc), btcAmount)
    }

    func testDisplay() {
        let satAmount: UInt128 = 100000000

        let amount = Amount(
            quantity: satAmount,
            currency: BitcoinChain.default.mainContract
        )

        XCTAssertEqual(amount.display(units: .satoshi), "SAT 100,000,000")
        XCTAssertEqual(amount.display(), "BTC 1.00000000")
    }

    func testCodable() throws {
        try FOSAssertCodable(Amount<USD>.self)
    }
}
