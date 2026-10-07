// PriceRowTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

// Design § 6, "The price and the archived row" (§ 3.4, § 3.5): a price names two instances and carries no
// decimals; the base's decimals are read from the statement when the price meets an amount; the stored rows are the
// amount's `{instance, baseUnits}` and the price's `{quote, base, scaled}`, each decoded with no registry.

@Suite("The price and the archived row")
struct PriceRowTests {
    @Test func krakensPriceCostsAtFourForASizeAtTen() throws {
        let registry = Fixtures.registryWithHoldings()
        let mid = try Price(Amount(whole: 65_000, of: Fixtures.krakenUSD, in: registry), per: Fixtures.krakenXBT, in: registry)
        #expect(mid.quote == Fixtures.krakenUSD)
        #expect(mid.base == Fixtures.krakenXBT)
        let size = Amount(baseUnits: 1_500_000_000, of: Fixtures.krakenXBT)            // 0.15 XBT at 10
        #expect(try mid.cost(of: size, in: registry) == Amount(baseUnits: 97_500_000, of: Fixtures.krakenUSD))   // 9750.0000
    }

    @Test func aFillAtTenStatesThePricePerWholeBase() throws {
        let registry = Fixtures.registryWithHoldings()
        let fill = try Price(Amount(baseUnits: 97_500_000, of: Fixtures.krakenUSD),
                             per: Amount(baseUnits: 1_500_000_000, of: Fixtures.krakenXBT), in: registry)
        #expect(try fill == Price(Amount(whole: 65_000, of: Fixtures.krakenUSD, in: registry), per: Fixtures.krakenXBT, in: registry))
    }

    @Test func aCostAgainstARegistryLackingTheBaseThrows() throws {
        let registry = Fixtures.registryWithHoldings()
        let mid = try Price(Amount(whole: 65_000, of: Fixtures.krakenUSD, in: registry), per: Fixtures.krakenXBT, in: registry)
        let lacking = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(throws: AssetRegistryError.undeclaredInstance(Fixtures.krakenXBT)) {
            try mid.cost(of: Amount(baseUnits: 1, of: Fixtures.krakenXBT), in: lacking)
        }
    }

    @Test func aPricePerAnUndeclaredBaseThrows() throws {
        let lacking = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(throws: AssetRegistryError.undeclaredInstance(Fixtures.krakenXBT)) {
            try Price(Amount(baseUnits: 1, of: Fixtures.krakenUSD), per: Fixtures.krakenXBT, in: lacking)
        }
        #expect(throws: AssetRegistryError.undeclaredInstance(Fixtures.krakenXBT)) {
            try Price(Amount(baseUnits: 1, of: Fixtures.krakenUSD), per: Amount(baseUnits: 1, of: Fixtures.krakenXBT), in: lacking)
        }
    }

    @Test(arguments: [Int128.max, .min, 12_345_678])
    func theAmountRowDecodesWithNoRegistry(baseUnits: Int128) throws {
        let row = #"{"instance":"exchange:binance:USDT","baseUnits":\#(baseUnits)}"#
        let decoded: Amount = try row.fromJSON()
        #expect(decoded == Amount(baseUnits: baseUnits, of: Fixtures.binanceUSDT))
        let encoded = try decoded.toJSON()
        #expect(encoded.contains(#""instance":"exchange:binance:USDT""#))
        #expect(encoded.contains(#""baseUnits":\#(baseUnits)"#))
        #expect(!encoded.contains("decimals"))
    }

    @Test(arguments: [Int128.max, .min, 65_000_000_000_000])
    func thePriceRowIsItsTwoInstancesAndItsScaledNumber(scaled: Int128) throws {
        let row = #"{"quote":"exchange:kraken:USD","base":"exchange:kraken:XBT","scaled":\#(scaled)}"#
        let decoded: Price = try row.fromJSON()
        #expect(decoded.quote == Fixtures.krakenUSD)
        #expect(decoded.base == Fixtures.krakenXBT)
        #expect(decoded.scaled == scaled)
        let again: Price = try decoded.toJSON().fromJSON()
        #expect(again == decoded)
        let object = try JSONSerialization.jsonObject(with: Data(decoded.toJSON().utf8)) as? [String: Any]
        #expect(Set(object?.keys.map { $0 } ?? []) == ["quote", "base", "scaled"])
    }

    @Test func aPriceMadeFromAnAmountRoundTripsToTheSameRow() throws {
        let registry = Fixtures.registryWithHoldings()
        let mid = try Price(Amount(whole: 65_000, of: Fixtures.krakenUSD, in: registry), per: Fixtures.krakenXBT, in: registry)
        #expect(mid.scaled == 650_000_000 * 1_000_000_000)
        let decoded: Price = try mid.toJSON().fromJSON()
        #expect(decoded == mid)
        #expect(try decoded.cost(of: Amount(baseUnits: 10_000_000_000, of: Fixtures.krakenXBT), in: registry)
                == Amount(whole: 65_000, of: Fixtures.krakenUSD, in: registry))
    }

    @Test func aMalformedInstanceInARowIsADecodingError() {
        let row = #"{"quote":"exchange:kraken","base":"exchange:kraken:XBT","scaled":1}"#
        #expect(throws: JSONError.self) {
            let _: Price = try row.fromJSON()
        }
    }
}
