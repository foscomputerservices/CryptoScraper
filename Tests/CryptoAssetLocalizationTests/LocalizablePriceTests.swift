// LocalizablePriceTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoAssetLocalization
import FOSFoundation
import FOSMVVM
import FOSTesting
import Foundation
import Testing

private typealias F = LocalizationFixtures

private func price(_ quote: Amount, per base: AssetInstance) -> Price {
    do { return try Price(quote, per: base) } catch { preconditionFailure("\(error)") }
}

private func price(_ quote: Amount, per size: Amount) -> Price {
    do { return try Price(quote, per: size) } catch { preconditionFailure("\(error)") }
}

// C11's DocC and § 8.2's planned tests for a price.
@Suite("LocalizablePrice")
struct LocalizablePriceTests: LocalizationStoreSuite {
    let locStore: LocalizationStore
    init() throws {
        self.locStore = try Self.testStore()
    }

    @Test func theMidInDollarsPerBitcoin() throws {
        let mid = try LocalizablePrice(price(F.whole(65_000, F.usd), per: F.btc), fractionDigits: 2)
        #expect(try text(mid, F.enUS) == "65,000.00 $ / BTC")
        #expect(try text(mid, F.deDE) == "65.000,00 $ / BTC")
    }

    @Test func everyDigitThePriceHoldsByDefault() throws {
        // The dollar's two digits and the nine below one cent.
        let mid = try LocalizablePrice(price(F.whole(65_000, F.usd), per: F.btc))
        #expect(mid.fractionDigits == 11)
        #expect(try text(mid, F.enUS) == "65,000.00000000000 $ / BTC")
    }

    @Test func aSubUnitPriceRendersItsNineDigits() throws {
        // 4 satoshi for 10 dollars: 0.4 satoshi a dollar, below one base unit of the quote.
        let fill = try LocalizablePrice(price(Amount(baseUnits: 4, of: F.btc), per: F.whole(10, F.usd)))
        #expect(fill.fractionDigits == 17)
        #expect(try text(fill, F.enUS) == "0.00000000400000000 ₿ / USD")
        #expect(try text(fill, F.deDE) == "0,00000000400000000 ₿ / USD")
    }

    @Test func fractionDigitsCutTowardZero() throws {
        // 2 dollars for 3 bitcoin: 0.666… a bitcoin, cut at two places.
        let fill = try LocalizablePrice(price(F.whole(2, F.usd), per: F.whole(3, F.btc)), fractionDigits: 2)
        #expect(try text(fill, F.enUS) == "0.66 $ / BTC")

        let capped = try LocalizablePrice(price(F.whole(2, F.usd), per: F.whole(3, F.btc)), fractionDigits: 40)
        #expect(capped.fractionDigits == 11)
        #expect(try text(capped, F.enUS) == "0.66666666666 $ / BTC")
    }

    @Test func anUndeclaredInstanceIsRefused() {
        #expect(throws: AssetRegistryError.self) {
            _ = try LocalizablePrice(.stub())
        }
    }

    @Test func comparableByThePrice() throws {
        let bid = try LocalizablePrice(price(F.whole(64_999, F.usd), per: F.btc))
        let ask = try LocalizablePrice(price(F.whole(65_001, F.usd), per: F.btc))
        #expect(bid < ask)
        #expect([ask, bid].sorted() == [bid, ask])
        #expect(try LocalizablePrice(price(F.whole(65_000, F.usd), per: F.btc)).value == price(F.whole(65_000, F.usd), per: F.btc))
    }

    @Test func neverEmptyAndPendingUntilLocalized() throws {
        let mid = try LocalizablePrice(price(F.whole(65_000, F.usd), per: F.btc))
        #expect(!mid.isEmpty)
        #expect(mid.localizationStatus == .localizationPending)
        #expect(throws: LocalizerError.self) {
            _ = try mid.localizedString
        }
    }
}
