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
    // Carried in step 4c of the identity PR: the wire's number counts in the instance the call names, so each call names
    // the test asset's home instance.
    static let btcHome = try! AssetInstance(validating: btc.id)
    static let usdcHome = try! AssetInstance(validating: usdc.id)

    @Test func anAmountReadsExactlyAndWritesBackTheSameText() throws {
        let size = try WireDecimal(parsing: "0.00012500").amount(of: Self.btcHome)
        #expect(size == Amount(baseUnits: 12_500, asset: Self.btc))
        #expect(try WireDecimal(size).text == "0.000125")
    }

    @Test func aPriceReadsExactlyAndWritesBackTheSameText() throws {
        let price = try WireDecimal(parsing: "65000.5").price(of: Self.usdcHome, per: Self.btcHome)
        #expect(price == Price(Amount(baseUnits: 65_000_500_000, asset: Self.usdc), per: Self.btc))
        #expect(try WireDecimal(price).text == "65000.5")
    }

    @Test func aPriceBelowTheQuotesBaseUnitWritesEveryDigit() throws {
        let price = try WireDecimal(parsing: "0.000000123").price(of: Self.usdcHome, per: Self.btcHome)
        #expect(try WireDecimal(price).text == "0.000000123")
    }

    @Test(arguments: ["65000", "1", "0.1", "123.456"])
    func aWholeNumberWritesWithNoPoint(text: String) throws {
        #expect(try WireDecimal(WireDecimal(parsing: text).amount(of: Self.usdcHome)).text == text)
    }

    @Test func aTurnoverFinerThanTheQuoteIsCutTowardZero() throws {
        #expect(try WireDecimal(parsing: "1994433.2905599999").amountCutTowardZero(of: Self.usdcHome) == Amount(baseUnits: 1_994_433_290_559, asset: Self.usdc))
        #expect(try WireDecimal(parsing: "-1.0000019").amountCutTowardZero(of: Self.usdcHome) == Amount(baseUnits: -1_000_001, asset: Self.usdc))
        #expect(try WireDecimal(parsing: "392436140.65").amountCutTowardZero(of: Self.usdcHome) == Amount(baseUnits: 392_436_140_650_000, asset: Self.usdc))
    }

    @Test func aProductIsExact() throws {
        #expect(try WireDecimal(parsing: "2101.23007377").times(WireDecimal(parsing: "85554.55")) == WireDecimal(parsing: "179769793.4078591535"))
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


// Step 4c of the identity PR: the `Asset`-typed forms that counted in an asset's home instance are gone; each form
// counts in the instance its call names. Tether's class is the library's, its home Ethereum's at 6; a second instance
// at 8 on the reserved fake chain stands in for an exchange's holding (Binance's tether at 8, design § 2.1).
@Suite("The wire's number counts in the instance the call names")
struct WireDecimalInstanceTests {
    static let atEight = AssetInstance.stub(address: "tether-at-8")

    static func registry() throws -> AssetRegistry {
        let library = AssetRegistry.libraryDeclarations.first { $0.asset == .usdt }!
        let tether = try AssetDeclaration(
            asset: library.asset, tokenName: library.tokenName, symbol: library.symbol,
            instances: [library.instances[0], AssetDeclaration.Instance(instance: atEight, decimals: 8, symbol: library.symbol)]
        )
        return try AssetRegistry(AssetRegistry.libraryDeclarations.filter { $0.asset != .usdt } + [tether])
    }

    static var home: AssetInstance { AssetRegistry.libraryDeclarations.first { $0.asset == .usdt }!.instances[0].instance }

    @Test func anAmountCountsInTheNamedInstanceNotItsClassesHome() throws {
        let registry = try Self.registry()
        let dust = try WireDecimal(parsing: "0.12345678")
        #expect(try dust.amount(of: Self.atEight, in: registry) == Amount(baseUnits: 12_345_678, of: Self.atEight))
        #expect(throws: AmountError.belowBaseUnit("0.12345678", decimals: 6)) { try dust.amount(of: Self.home, in: registry) }
    }

    @Test func aCutAmountCountsInTheNamedInstanceNotItsClassesHome() throws {
        let registry = try Self.registry()
        let text = try WireDecimal(parsing: "0.123456789")
        #expect(try text.amountCutTowardZero(of: Self.atEight, in: registry) == Amount(baseUnits: 12_345_678, of: Self.atEight))
        #expect(try text.amountCutTowardZero(of: Self.home, in: registry) == Amount(baseUnits: 123_456, of: Self.home))
    }

    @Test func aPriceNamesTheTwoInstancesOfItsCall() throws {
        let registry = try Self.registry()
        let price = try WireDecimal(parsing: "65000.12345678").price(of: Self.atEight, per: Self.home, in: registry)
        #expect(price.quote == Self.atEight)
        #expect(price.base == Self.home)
        // one whole base unit (10^6 of the home's base units) costs 65000.12345678 at 8 decimals
        #expect(try price.cost(of: Amount(baseUnits: 1_000_000, of: Self.home), in: registry)
            == Amount(baseUnits: 6_500_012_345_678, of: Self.atEight))
    }
}
