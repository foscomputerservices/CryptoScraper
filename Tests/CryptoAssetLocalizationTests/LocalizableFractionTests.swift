// LocalizableFractionTests.swift
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

// C11's DocC and § 8.2's planned tests for a fraction.
@Suite("LocalizableFraction")
struct LocalizableFractionTests: LocalizationStoreSuite {
    let locStore: LocalizationStore
    init() throws {
        self.locStore = try Self.testStore()
    }

    @Test func aSlippageStep() throws {
        let step = LocalizableFraction(Fraction(basisPoints: 25))
        #expect(step.fractionDigits == 2)
        #expect(!step.showsSign)
        #expect(try text(step, F.enUS) == "0.25 %")
        #expect(try text(step, F.deDE) == "0,25 %")
    }

    @Test func aGainWithItsSign() throws {
        let gain = LocalizableFraction(Fraction(basisPoints: 1_250), showsSign: true)
        #expect(try text(gain, F.enUS) == NumberFormatter.plus(F.enUS) + "12.50 %")
        #expect(try text(gain, F.deDE) == NumberFormatter.plus(F.deDE) + "12,50 %")
        #expect(try text(LocalizableFraction(Fraction(basisPoints: 1_250)), F.enUS) == "12.50 %")
    }

    @Test func aLossCarriesTheLocalesMinus() throws {
        let loss = LocalizableFraction(Fraction(percent: -3), showsSign: true)
        #expect(try text(loss, F.enUS) == NumberFormatter.minus(F.enUS) + "3.00 %")
        #expect(try text(LocalizableFraction(Fraction(percent: -3)), F.enUS) == NumberFormatter.minus(F.enUS) + "3.00 %")
    }

    @Test func zeroCarriesNoSign() throws {
        #expect(try text(LocalizableFraction(.zero, showsSign: true), F.enUS) == "0.00 %")
    }

    @Test func fractionDigitsCutTowardZero() throws {
        // Two thirds is 66.6666666 percentage points: 66.66 at two places, never 66.67.
        let twoThirds = Fraction(Amount(baseUnits: 2, of: F.usd), over: Amount(baseUnits: 3, of: F.usd))
        #expect(try text(LocalizableFraction(twoThirds), F.enUS) == "66.66 %")
        #expect(try text(LocalizableFraction(twoThirds, fractionDigits: 7), F.enUS) == "66.6666666 %")
        #expect(try text(LocalizableFraction(twoThirds, fractionDigits: 0), F.enUS) == "66 %")
    }

    @Test func fractionDigitsAreAtMostSeven() throws {
        let capped = LocalizableFraction(Fraction(basisPoints: 1), fractionDigits: 12)
        #expect(capped.fractionDigits == 7)
        #expect(try text(capped, F.enUS) == "0.0100000 %")
    }

    @Test func aLargeFractionIsGrouped() throws {
        #expect(try text(LocalizableFraction(Fraction(integer: 25)), F.enUS) == "2,500.00 %")
        #expect(try text(LocalizableFraction(Fraction(integer: 25)), F.deDE) == "2.500,00 %")
    }

    @Test func comparableByTheFraction() {
        let less = LocalizableFraction(Fraction(basisPoints: 24))
        let more = LocalizableFraction(Fraction(basisPoints: 25))
        #expect(less < more)
        #expect([more, less].sorted() == [less, more])
        #expect(more.value == Fraction(basisPoints: 25))
    }

    @Test func neverEmptyAndPendingUntilLocalized() {
        let step = LocalizableFraction(Fraction(basisPoints: 25))
        #expect(!step.isEmpty)
        #expect(step.localizationStatus == .localizationPending)
        #expect(throws: LocalizerError.self) {
            _ = try step.localizedString
        }
    }
}
