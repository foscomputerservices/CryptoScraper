// WireDecimalTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import Foundation
import Testing

// The one parse of an exchange's number text and its one way back out (C3, C30): exact both ways, never a Double.

@Suite("The wire's number text")
struct WireDecimalTests {
    static let btc = try! Asset(symbol: "BTC", unitExponent: 8)
    static let usdc = try! Asset(symbol: "USDC", unitExponent: 6)

    @Test func anAmountReadsExactlyAndWritesBackTheSameText() throws {
        let size = try WireDecimal(parsing: "0.00012500").amount(of: Self.btc)
        #expect(size == Amount(baseUnits: 12_500, asset: Self.btc))
        #expect(WireDecimal(size).text == "0.000125")
    }

    @Test func aPriceReadsExactlyAndWritesBackTheSameText() throws {
        let price = try WireDecimal(parsing: "65000.5").price(of: Self.usdc, per: Self.btc)
        #expect(price == Price(Amount(baseUnits: 65_000_500_000, asset: Self.usdc), per: Self.btc))
        #expect(WireDecimal(price).text == "65000.5")
    }

    @Test func aPriceBelowTheQuotesBaseUnitWritesEveryDigit() throws {
        let price = try WireDecimal(parsing: "0.000000123").price(of: Self.usdc, per: Self.btc)
        #expect(WireDecimal(price).text == "0.000000123")
    }

    @Test(arguments: ["65000", "1", "0.1", "123.456"])
    func aWholeNumberWritesWithNoPoint(text: String) throws {
        #expect(try WireDecimal(WireDecimal(parsing: text).amount(of: Self.usdc)).text == text)
    }

    @Test func aFundingRateIsAnExactFraction() throws {
        let eighthOfABasisPoint = Fraction(Amount(whole: 125, of: Self.btc), over: Amount(whole: 10_000_000, of: Self.btc))
        #expect(try WireDecimal(parsing: "0.0000125").fraction() == eighthOfABasisPoint)
    }

    @Test func aRateFinerThanNineDigitsIsBelowBaseUnit() {
        #expect(throws: AmountError.belowBaseUnit("0.0000000001", unitExponent: 9)) {
            try WireDecimal(parsing: "0.0000000001").fraction()
        }
    }

    @Test func theMidpointIsExact() throws {
        let mid = WireDecimal.midpoint(try WireDecimal(parsing: "100.1"), try WireDecimal(parsing: "100.2"))
        #expect(mid.text == "100.15")
        #expect(WireDecimal.midpoint(try WireDecimal(parsing: "3"), try WireDecimal(parsing: "4")).text == "3.5")
    }

    @Test func aCountIsAWholeNumber() throws {
        #expect(try WireDecimal(parsing: "50").integer() == 50)
        #expect(throws: AmountError.belowBaseUnit("2.5", unitExponent: 0)) {
            try WireDecimal(parsing: "2.5").integer()
        }
    }

    @Test(arguments: ["1e5", "+1", "1,000.00", " 1", "1..2", ".5", "5.", "", "-", "abc"])
    func malformedTextIsRefused(text: String) {
        #expect(throws: AmountError.malformedText(text)) {
            try WireDecimal(parsing: text)
        }
    }

    @Test func theTextDecodesFromJSONAsAString() throws {
        let decoded: [WireDecimal] = try JSONDecoder().decode([WireDecimal].self, from: Data(#"["1.50","2"]"#.utf8))
        #expect(decoded.map(\.text) == ["1.5", "2"])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([WireDecimal].self, from: Data("[1.5]".utf8))
        }
    }
}
