// LocalizingEncoderTests.swift
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

// § 8.2's last planned test: through FOSMVVM's localizing encoder, a ViewModel carrying the three types encodes with
// its text localized, and the localized values round-trip through the plain encoder with their text.
@Suite("The localizing encoder")
struct LocalizingEncoderTests: LocalizationStoreSuite {
    let locStore: LocalizationStore
    init() throws {
        self.locStore = try Self.testStore()
    }

    @Test func aViewModelCarryingTheThreeIsLocalized() throws {
        let holding = try HoldingViewModel.pending()
        #expect(holding.balance.localizationStatus == .localizationPending)

        let english: HoldingViewModel = try holding.toJSON(encoder: encoder(locale: F.enUS)).fromJSON()
        #expect(english.balance.localizationStatus == .localized)
        #expect(english.mid.localizationStatus == .localized)
        #expect(english.gain.localizationStatus == .localized)
        #expect(try english.balance.localizedString == "1,234.56 $")
        #expect(try english.mid.localizedString == "65,000.00 $ / BTC")
        #expect(try english.gain.localizedString == NumberFormatter.plus(F.enUS) + "12.50 %")

        let german: HoldingViewModel = try holding.toJSON(encoder: encoder(locale: F.deDE)).fromJSON()
        #expect(try german.balance.localizedString == "1.234,56 $")
        #expect(try german.mid.localizedString == "65.000,00 $ / BTC")
        #expect(try german.gain.localizedString == NumberFormatter.plus(F.deDE) + "12,50 %")
    }

    @Test func theValuesSurviveTheLocalizingRoundTrip() throws {
        let holding = try HoldingViewModel.pending()
        let decoded: HoldingViewModel = try holding.toJSON(encoder: encoder(locale: F.deDE)).fromJSON()
        #expect(decoded.balance == holding.balance)
        #expect(decoded.balance.value == holding.balance.value)
        #expect(decoded.balance.unit == holding.balance.unit)
        #expect(decoded.mid.value == holding.mid.value)
        #expect(decoded.gain.value == holding.gain.value)
    }

    @Test func expectTranslationsPassesForEachType() throws {
        try expectTranslations(LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd)))
        try expectTranslations(LocalizablePrice(Price(F.whole(65_000, F.usd), per: F.btc)))
        try expectTranslations(LocalizableFraction(Fraction(basisPoints: 25)))
    }

    @Test func aLocalizedValueRoundTripsThroughThePlainEncoder() throws {
        let localized: LocalizableAmount = try LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd))
            .toJSON(encoder: encoder(locale: F.deDE)).fromJSON()
        let again: LocalizableAmount = try localized.toJSON(encoder: JSONEncoder()).fromJSON()
        #expect(again.localizationStatus == .localized)
        #expect(try again.localizedString == "1.234,56 $")
        #expect(again == localized)

        let price: LocalizablePrice = try LocalizablePrice(Price(F.whole(65_000, F.usd), per: F.btc), fractionDigits: 2)
            .toJSON(encoder: encoder(locale: F.enUS)).fromJSON()
        let priceAgain: LocalizablePrice = try price.toJSON(encoder: JSONEncoder()).fromJSON()
        #expect(try priceAgain.localizedString == "65,000.00 $ / BTC")

        let fraction: LocalizableFraction = try LocalizableFraction(Fraction(basisPoints: 25))
            .toJSON(encoder: encoder(locale: F.enUS)).fromJSON()
        let fractionAgain: LocalizableFraction = try fraction.toJSON(encoder: JSONEncoder()).fromJSON()
        #expect(try fractionAgain.localizedString == "0.25 %")
    }

    @Test func aPendingValueNeedsTheLocalizingEncoder() throws {
        #expect(throws: LocalizerError.self) {
            _ = try LocalizableAmount(Amount(baseUnits: 1, of: F.usd)).toJSON(encoder: JSONEncoder())
        }
        #expect(throws: LocalizerError.self) {
            _ = try LocalizableFraction(Fraction(basisPoints: 1)).toJSON(encoder: JSONEncoder())
        }
    }

    @Test func aDecodedValueNeedsNoRegistry() throws {
        // An amount of an instance the shared registry never declared decodes and keeps its text.
        let stubbed = LocalizableAmount.stub()
        let decoded: LocalizableAmount = try stubbed.toJSON(encoder: JSONEncoder()).fromJSON()
        #expect(decoded == stubbed)
        #expect(try decoded.localizedString == "0.042 pebble")
    }
}

@ViewModel
private struct HoldingViewModel {
    let balance: LocalizableAmount
    let mid: LocalizablePrice
    let gain: LocalizableFraction
    var vmId: ViewModelId

    static func stub() -> Self {
        .init(balance: .stub(), mid: .stub(), gain: .stub(), vmId: .init())
    }

    // Values not yet localized, as a factory makes them on the server.
    static func pending() throws -> Self {
        try .init(
            balance: LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd)),
            mid: LocalizablePrice(Price(F.whole(65_000, F.usd), per: F.btc), fractionDigits: 2),
            gain: LocalizableFraction(Fraction(basisPoints: 1_250), showsSign: true),
            vmId: .init()
        )
    }
}
