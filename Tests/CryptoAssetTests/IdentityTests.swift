// IdentityTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Identity")
struct IdentityTests {
    @Test func oneSymbolAndExponentWithDifferentNamesIsOneAsset() throws {
        let named = try Asset(symbol: "USDC", unitExponent: 6, wholeUnit: .init(name: "usd coin", symbol: "◎"))
        let unnamed = try Asset(symbol: "usdc", unitExponent: 6)

        #expect(named == unnamed)
        #expect(named == .usdc)
        #expect(named.hashValue == unnamed.hashValue)
        #expect(Set([named, unnamed, .usdc]).count == 1)

        let sum = Amount(baseUnits: 1, asset: named) + Amount(baseUnits: 2, asset: unnamed)
        #expect(sum.baseUnits == 3)
    }

    @Test func aDifferentExponentIsADifferentAsset() throws {
        #expect(try Asset(symbol: "USDC", unitExponent: 18) != .usdc)
    }

    @Test(arguments: [31, -1])
    func aUnitExponentOutOfRangeThrows(exponent: Int) {
        #expect(throws: AssetError.unitExponentOutOfRange(exponent)) {
            try Asset(symbol: "BTC", unitExponent: exponent)
        }
    }

    @Test func theRangeIsZeroThroughThirty() throws {
        #expect(try Asset(symbol: "ZERO", unitExponent: 0).unitExponent == 0)
        #expect(try Asset(symbol: "THIRTY", unitExponent: 30).unitExponent == 30)
    }

    @Test func aUnitAboveTheAssetsExponentThrows() {
        let nine = Asset.Unit(name: "nine", exponent: 9)
        #expect(throws: AssetError.unitOutOfRange(nine)) {
            try Asset(symbol: "BTC", unitExponent: 8, between: [nine])
        }
    }

    @Test func neverWithoutAUnit() throws {
        let usdc = try Asset(symbol: "USDC", unitExponent: 6)
        #expect(usdc.wholeUnit.name == "USDC")
        #expect(usdc.wholeUnit.exponent == 6)
        #expect(usdc.baseUnit == nil)
        #expect(usdc.units == [usdc.wholeUnit])
        #expect(usdc.displayUnit == usdc.wholeUnit)
    }

    @Test func theUnitsInOrder() {
        let eth = Asset.eth
        #expect(eth.wholeUnit.exponent == 18)
        #expect(eth.baseUnit?.name == "wei")
        #expect(eth.units.map(\.name) == ["wei", "gwei", "ether"])
        #expect(eth.unit(named: "gwei") == Fixtures.gwei)
        #expect(eth.unit(named: "finney") == nil)
    }

    @Test func theShippedConstants() {
        #expect(Asset.usd.unitExponent == 2)
        #expect(Asset.usd.wholeUnit == .init(name: "dollar", exponent: 2, symbol: "$", fractionDigits: 2))
        #expect(Asset.usd.baseUnit == .init(name: "cent", exponent: 0, symbol: "¢"))
        #expect(Asset.usdc.unitExponent == 6)
        #expect(Asset.usdt.unitExponent == 6)
        #expect(Asset.btc.unitExponent == 8)
        #expect(Asset.btc.baseUnit?.name == "satoshi")
        #expect(Asset.btc.wholeUnit.symbol == "₿")
        #expect(Asset.eth.unitExponent == 18)
        #expect(Asset.eth.wholeUnit.symbol == "Ξ")
    }
}
