import Testing
import Foundation
import CryptoAsset
import FOSMVVM
import CryptoAssetLocalization

@Suite("C10 LocalizableAmount: the text a reader sees")
struct LocalizableAmountTextTests {
    @Test("C10, §8.2: 123_456 base units of a 2-decimal dollar read 1,234.56 $ in en_US")
    func groupedWithPointInEnglish() throws {
        let amount = LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar()))
        #expect(try Fixture.text(amount, Fixture.enUS) == "1,234.56 $")
    }

    @Test("C10, §8.2: the same amount reads 1.234,56 $ in de_DE")
    func groupedWithCommaInGerman() throws {
        let amount = LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar()))
        #expect(try Fixture.text(amount, Fixture.deDE) == "1.234,56 $")
    }

    @Test("C10, §8.2: showsSymbol false drops the sign in both locales")
    func symbolAbsent() throws {
        let amount = LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar()), showsSymbol: false)
        #expect(try Fixture.text(amount, Fixture.enUS) == "1,234.56")
        #expect(try Fixture.text(amount, Fixture.deDE) == "1.234,56")
    }

    @Test("C10: the symbol is the unit's sign, never the asset's symbol, when the unit has a sign")
    func signBeatsSymbol() throws {
        let text = try #require(try Fixture.text(LocalizableAmount(Fixture.amount(123_456, of: Fixture.dollar())), Fixture.enUS))
        #expect(text.hasSuffix("$"))
        #expect(!text.contains("TKU"))
    }

    @Test("C10, §8.2: an asset with no unit names renders its symbol (12_500 base units of 8 decimals)")
    func symbolWhenNoUnitNames() throws {
        let amount = LocalizableAmount(Fixture.amount(12_500, of: Fixture.eightDecimals()))
        #expect(try Fixture.text(amount, Fixture.enUS) == "0.00012500 TKA")
        #expect(try Fixture.text(amount, Fixture.deDE) == "0,00012500 TKA")
    }

    @Test("C10, §8.2: in: satoshi renders 12,500 satoshi (de_DE 12.500 satoshi)")
    func chosenUnit() throws {
        let amount = LocalizableAmount(Fixture.amount(12_500, of: Fixture.eightDecimals()), in: Fixture.satoshi())
        #expect(try Fixture.text(amount, Fixture.enUS) == "12,500 satoshi")
        #expect(try Fixture.text(amount, Fixture.deDE) == "12.500 satoshi")
    }

    @Test("C10: a chosen unit with showsSymbol false is the bare number")
    func chosenUnitWithoutSymbol() throws {
        let amount = LocalizableAmount(Fixture.amount(12_500, of: Fixture.eightDecimals()), in: Fixture.satoshi(), showsSymbol: false)
        #expect(try Fixture.text(amount, Fixture.enUS) == "12,500")
    }

    @Test("C10, §8.2: a negative amount carries the locale's minus before the number")
    func negativeCarriesLocaleMinus() throws {
        let amount = LocalizableAmount(Fixture.amount(-123_456, of: Fixture.dollar()))
        #expect(try Fixture.text(amount, Fixture.enUS) == "\(Fixture.minus(Fixture.enUS))1,234.56 $")
        #expect(try Fixture.text(amount, Fixture.deDE) == "\(Fixture.minus(Fixture.deDE))1.234,56 $")
    }

    @Test("C10: zero reads with its fraction digits")
    func zero() throws {
        #expect(try Fixture.text(LocalizableAmount(Fixture.amount(0, of: Fixture.dollar())), Fixture.enUS) == "0.00 $")
    }

    @Test("C10: an amount below one whole unit keeps its leading zero and its digits")
    func belowOneWholeUnit() throws {
        #expect(try Fixture.text(LocalizableAmount(Fixture.amount(5, of: Fixture.dollar())), Fixture.enUS) == "0.05 $")
    }

    @Test("C10: trailing zeros are kept to the fraction digits, not trimmed")
    func trailingZerosKept() throws {
        #expect(try Fixture.text(LocalizableAmount(Fixture.amount(123_400, of: Fixture.dollar())), Fixture.enUS) == "1,234.00 $")
    }

    @Test("C10, R12: no Double is formed; 2^53 + 1 base units keep their last digit")
    func exactPastDoublePrecision() throws {
        let amount = LocalizableAmount(Fixture.amount(9_007_199_254_740_993, of: Fixture.dollar()))
        #expect(try Fixture.text(amount, Fixture.enUS) == "90,071,992,547,409.93 $")
    }

    @Test("C10, §8.2: an 18-exponent asset at 10^24 base units renders every digit")
    func eighteenExponentAtTenToTheTwentyFour() throws {
        let amount = LocalizableAmount(Fixture.amount(digits: "1000000000000000000000000", of: Fixture.eighteenDecimals()), fractionDigits: 18)
        #expect(try Fixture.text(amount, Fixture.enUS) == "1,000,000.000000000000000000 TKB")
        #expect(try Fixture.text(amount, Fixture.deDE) == "1.000.000,000000000000000000 TKB")
    }

    @Test("C10, §8.2: an 18-exponent amount whose 25 digits are all distinct renders each of them")
    func eighteenExponentEveryDigit() throws {
        let amount = LocalizableAmount(Fixture.amount(digits: "1234567890123456789012345", of: Fixture.eighteenDecimals()), fractionDigits: 18)
        #expect(try Fixture.text(amount, Fixture.enUS) == "1,234,567.890123456789012345 TKB")
        #expect(try Fixture.text(amount, Fixture.deDE) == "1.234.567,890123456789012345 TKB")
    }

    @Test("C10: with no fractionDigits given, an 18-exponent no-unit-names asset shows all 18 digits")
    func eighteenExponentDefaultDigits() throws {
        let amount = LocalizableAmount(Fixture.amount(digits: "1234567890123456789012345", of: Fixture.eighteenDecimals()))
        #expect(try Fixture.text(amount, Fixture.enUS) == "1,234,567.890123456789012345 TKB")
    }
}

@Suite("C10 LocalizableAmount: cut toward zero, never rounded")
struct LocalizableAmountCutTests {
    // 1_999_999_999 base units of 8 decimals is 19.99999999

    @Test("C10, §8.2: fractionDigits 2 cuts 19.99999999 to 19.99, never up to 20.00")
    func cutNeverRoundsUp() throws {
        let amount = LocalizableAmount(Fixture.amount(1_999_999_999, of: Fixture.eightDecimals()), fractionDigits: 2)
        #expect(try Fixture.text(amount, Fixture.enUS) == "19.99 TKA")
        #expect(try Fixture.text(amount, Fixture.deDE) == "19,99 TKA")
    }

    @Test("C10: a negative amount is cut toward zero too, -19.99999999 to -19.99")
    func negativeCutTowardZero() throws {
        let amount = LocalizableAmount(Fixture.amount(-1_999_999_999, of: Fixture.eightDecimals()), fractionDigits: 2)
        #expect(try Fixture.text(amount, Fixture.enUS) == "\(Fixture.minus(Fixture.enUS))19.99 TKA")
    }

    @Test("C10: fractionDigits 0 leaves the whole part alone, 19 not 20")
    func zeroFractionDigits() throws {
        let amount = LocalizableAmount(Fixture.amount(1_999_999_999, of: Fixture.eightDecimals()), fractionDigits: 0)
        #expect(try Fixture.text(amount, Fixture.enUS) == "19 TKA")
    }

    @Test("C10: fractionDigits above the exponent are held at the exponent, 8 digits and no padding")
    func neverMoreThanTheExponent() throws {
        let amount = LocalizableAmount(Fixture.amount(1_999_999_999, of: Fixture.eightDecimals()), fractionDigits: 12)
        #expect(try Fixture.text(amount, Fixture.enUS) == "19.99999999 TKA")
    }

    @Test("C10, §8.2: fractionDigits 2 on a 4-decimal gain cuts 9,750.9999 to 9,750.99")
    func gainCutForTheReader() throws {
        let instance = Fixture.eightDecimals()
        let amount = LocalizableAmount(Fixture.amount(975_099_990_000, of: instance), fractionDigits: 2)
        #expect(try Fixture.text(amount, Fixture.enUS) == "9,750.99 TKA")
    }
}
