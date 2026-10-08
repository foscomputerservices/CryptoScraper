// LocalizableAmountContractTests.swift
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

// C10's DocC and § 8.2's planned tests, each example's text in en_US and in de_DE.
@Suite("LocalizableAmount")
struct LocalizableAmountContractTests: LocalizationStoreSuite {
    let locStore: LocalizationStore
    init() throws {
        self.locStore = try Self.testStore()
    }

    @Test func dollarsInTheReadersLocale() throws {
        let balance = try LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd))
        #expect(try text(balance, F.enUS) == "1,234.56 $")
        #expect(try text(balance, F.deDE) == "1.234,56 $")
    }

    @Test func theDisplayUnitAndItsFractionDigitsByDefault() throws {
        let size = try LocalizableAmount(Amount(baseUnits: 12_500, of: F.btc))
        #expect(try size.unit == AssetRegistry.shared.declaration(of: .btc).displayUnit)
        #expect(size.fractionDigits == 8)
        #expect(try text(size, F.enUS) == "0.00012500 ₿")
        #expect(try text(size, F.deDE) == "0,00012500 ₿")
    }

    @Test func showsSymbolFalseDropsTheSign() throws {
        let fee = try LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd), showsSymbol: false)
        #expect(try text(fee, F.enUS) == "1,234.56")
        #expect(try text(fee, F.deDE) == "1.234,56")
    }

    @Test func aNegativeAmountCarriesTheLocalesMinus() throws {
        let loss = try LocalizableAmount(Amount(baseUnits: -123_456, of: F.usd))
        let minus = NumberFormatter.minus(F.enUS)
        #expect(try text(loss, F.enUS) == minus + "1,234.56 $")
        #expect(try text(loss, F.deDE) == NumberFormatter.minus(F.deDE) + "1.234,56 $")
    }

    @Test func anEighteenExponentAssetRendersEveryDigit() throws {
        // 10^24 wei is a million ether; one wei more shows in the last place.
        let million = Amount(baseUnits: 1_000_000_000_000_000_000_000_000, of: F.eth)
        let andOneWei = Amount(baseUnits: 1_000_000_000_000_000_000_000_001, of: F.eth)
        #expect(try text(LocalizableAmount(million), F.enUS) == "1,000,000.000000000000000000 Ξ")
        #expect(try text(LocalizableAmount(andOneWei), F.enUS) == "1,000,000.000000000000000001 Ξ")
        #expect(try text(LocalizableAmount(andOneWei), F.deDE) == "1.000.000,000000000000000001 Ξ")
    }

    @Test func theWidestAmountRendersEveryDigit() throws {
        let widest = try LocalizableAmount(Amount(baseUnits: .max, of: F.eth))
        #expect(try text(widest, F.enUS) == "170,141,183,460,469,231,731.687303715884105727 Ξ")
        let narrowest = try LocalizableAmount(Amount(baseUnits: .min, of: F.eth))
        #expect(try text(narrowest, F.enUS) == NumberFormatter.minus(F.enUS) + "170,141,183,460,469,231,731.687303715884105728 Ξ")
    }

    @Test func fractionDigitsCutTowardZeroAndNeverRoundUp() throws {
        // 123.45678999 BTC to two places is 123.45, never 123.46.
        let gain = try LocalizableAmount(Amount(baseUnits: 12_345_678_999, of: F.btc), fractionDigits: 2)
        #expect(gain.fractionDigits == 2)
        #expect(try text(gain, F.enUS) == "123.45 ₿")
        #expect(try text(gain, F.deDE) == "123,45 ₿")

        // A negative amount is cut toward zero too: its magnitude is cut.
        let loss = try LocalizableAmount(Amount(baseUnits: -12_345_678_999, of: F.btc), fractionDigits: 2)
        #expect(try text(loss, F.enUS) == NumberFormatter.minus(F.enUS) + "123.45 ₿")

        // Zero digits: the whole count alone, no point.
        let whole = try LocalizableAmount(Amount(baseUnits: 999_999_999, of: F.btc), fractionDigits: 0)
        #expect(try text(whole, F.enUS) == "9 ₿")
    }

    @Test func fractionDigitsAreNeverMoreThanTheExponent() throws {
        let dollars = try LocalizableAmount(Amount(baseUnits: 975_000, of: F.usd), fractionDigits: 6)
        #expect(dollars.fractionDigits == 2)
        #expect(try text(dollars, F.enUS) == "9,750.00 $")

        let none = try LocalizableAmount(Amount(baseUnits: 975_000, of: F.usd), fractionDigits: -1)
        #expect(none.fractionDigits == 0)
        #expect(try text(none, F.enUS) == "9,750 $")
    }

    @Test func inSatoshi() throws {
        let size = try LocalizableAmount(Amount(baseUnits: 12_500, of: F.btc), in: F.satoshi)
        #expect(size.unit == F.satoshi)
        #expect(size.fractionDigits == 0)
        #expect(try text(size, F.enUS) == "12,500 satoshi")
        #expect(try text(size, F.deDE) == "12.500 satoshi")
    }

    @Test func inCents() throws {
        let cent = try #require(AssetRegistry.shared.declaration(of: .usd).unit(named: "cent"))
        let cents = try LocalizableAmount(Amount(baseUnits: 123_456, of: F.usd), in: cent)
        #expect(try text(cents, F.enUS) == "123,456 ¢")
    }

    @Test func anAssetWithNoUnitNamesRendersItsSymbol() throws {
        let sol = try LocalizableAmount(F.whole(3, F.sol))
        #expect(try text(sol, F.enUS) == "3.000000000 SOL")
        #expect(try text(sol, F.deDE) == "3,000000000 SOL")
    }

    @Test func aUnitNotTheAssetsIsRefused() {
        #expect(throws: AssetError.unitOutOfRange(F.satoshi)) {
            _ = try LocalizableAmount(Amount(baseUnits: 1, of: F.usd), in: F.satoshi)
        }
    }

    @Test func anUndeclaredInstanceIsRefused() {
        #expect(throws: AssetRegistryError.undeclaredInstance(.stub())) {
            _ = try LocalizableAmount(Amount(baseUnits: 1, of: .stub()))
        }
    }

    @Test func comparableByTheAmount() throws {
        let less = try LocalizableAmount(Amount(baseUnits: 100, of: F.usd))
        let more = try LocalizableAmount(Amount(baseUnits: 101, of: F.usd))
        #expect(less < more)
        #expect(!(more < less))
        #expect([more, less].sorted() == [less, more])
    }

    @Test func theValueStaysExact() throws {
        let amount = Amount(baseUnits: 1_000_000_000_000_000_000_000_001, of: F.eth)
        #expect(try LocalizableAmount(amount).value == amount)
    }

    @Test func neverEmptyAndPendingUntilLocalized() throws {
        let balance = try LocalizableAmount(Amount(baseUnits: 1, of: F.usd))
        #expect(!balance.isEmpty)
        #expect(balance.localizationStatus == .localizationPending)
        #expect(throws: LocalizerError.self) {
            _ = try balance.localizedString
        }
    }
}

extension NumberFormatter {
    /// The locale's minus, as the library reads it
    static func minus(_ locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.minusSign
    }

    /// The locale's plus, as the library reads it
    static func plus(_ locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.plusSign
    }
}
