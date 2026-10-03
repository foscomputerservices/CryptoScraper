// C1_AssetSymbol.swift
//
// C1: an asset's symbol, as a typed value and not a string. R8.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("AssetSymbol — C1, R8 behavioral")
struct C1_AssetSymbolTests {

    // MARK: Upper-cased on the way in

    // C1: "A symbol is validated on the way in, upper-cased"
    @Test func aLowerCaseSymbolIsUpperCased() throws {
        let symbol = try AssetSymbol(validating: "fred")
        #expect(symbol.text == "FRED")
    }

    // C1: upper-cased on the way in
    @Test func aMixedCaseSymbolIsUpperCased() throws {
        let symbol = try AssetSymbol(validating: "bArNeY")
        #expect(symbol.text == "BARNEY")
    }

    // C1: an upper-case symbol keeps its text
    @Test func anUpperCaseSymbolKeepsItsText() throws {
        let symbol = try AssetSymbol(validating: "WILMA")
        #expect(symbol.text == "WILMA")
    }

    // C1: two spellings of one symbol in different cases are one symbol
    @Test func twoCasesOfOneSymbolAreEqualAndHashAlike() throws {
        let lower = try AssetSymbol(validating: "betty")
        let upper = try AssetSymbol(validating: "BETTY")
        #expect(lower == upper)
        #expect(Set([lower, upper]).count == 1)
    }

    // C1: different symbols are different values
    @Test func differentSymbolsAreNotEqual() throws {
        #expect(try AssetSymbol(validating: "FRED") != AssetSymbol(validating: "BARNEY"))
    }

    // MARK: Well-formed: letters, digits, a point, a dash, one to twelve characters

    // C1: one character is enough
    @Test func aOneCharacterSymbolIsAccepted() throws {
        #expect(try AssetSymbol(validating: "F").text == "F")
    }

    // C1: twelve characters is the most
    @Test func aTwelveCharacterSymbolIsAccepted() throws {
        #expect(try AssetSymbol(validating: "FREDFLINTSTO").text == "FREDFLINTSTO")
    }

    // C1: longer than twelve characters is malformed
    @Test func aThirteenCharacterSymbolIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "FREDFLINTSTON")
        }
        #expect(isMalformed(error))
    }

    // C1: digits are allowed
    @Test func aSymbolWithDigitsIsAccepted() throws {
        #expect(try AssetSymbol(validating: "1000fred42").text == "1000FRED42")
    }

    // C1: a point is allowed
    @Test func aSymbolWithAPointIsAccepted() throws {
        #expect(try AssetSymbol(validating: "fred.b").text == "FRED.B")
    }

    // C1: a dash is allowed
    @Test func aSymbolWithADashIsAccepted() throws {
        #expect(try AssetSymbol(validating: "bamm-bamm").text == "BAMM-BAMM")
    }

    // C1: "Throws AssetSymbolError when candidate is empty"
    @Test func anEmptySymbolIsEmpty() {
        #expect(throws: AssetSymbolError.empty) {
            try AssetSymbol(validating: "")
        }
    }

    // C1: a space is not a letter, a digit, a point or a dash
    @Test func aSymbolWithASpaceIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "FRED F")
        }
        #expect(isMalformed(error))
    }

    // C1: surrounding whitespace is not trimmed; it is a character outside the rule
    // UNRATIFIED-CLARIFICATION: nothing says the candidate is trimmed; the stricter reading is tested.
    @Test func aSymbolWithSurroundingWhitespaceIsRejected() {
        #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: " FRED ")
        }
    }

    // C1: whitespace only is not a symbol
    // UNRATIFIED-CLARIFICATION: empty or malformed is not said for whitespace only; either case is accepted.
    @Test func aWhitespaceOnlySymbolIsRejected() {
        #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "   ")
        }
    }

    // C1: an underscore is outside the rule
    @Test func aSymbolWithAnUnderscoreIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "FRED_42")
        }
        #expect(isMalformed(error))
    }

    // C1: a slash is outside the rule, so a pair is never a symbol
    @Test func aSymbolWithASlashIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "FRED/DINO")
        }
        #expect(isMalformed(error))
    }

    // C1: a currency sign is outside the rule
    @Test func aSymbolWithACurrencySignIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "$FRED")
        }
        #expect(isMalformed(error))
    }

    // C1: a letter outside the basic Latin alphabet
    // UNRATIFIED-CLARIFICATION: "a letter" is not said to be ASCII; the stricter reading (ASCII only) is tested.
    @Test func aSymbolWithAnAccentedLetterIsMalformed() {
        let error = #expect(throws: AssetSymbolError.self) {
            try AssetSymbol(validating: "FRÉD")
        }
        #expect(isMalformed(error))
    }

    // MARK: Decoding validates the same way

    // C1: a symbol survives its own encoding
    @Test func aSymbolRoundTripsThroughJSON() throws {
        let symbol = try AssetSymbol(validating: "FRED")
        #expect(try roundTrip(symbol) == symbol)
    }

    // C1: "decoding validates the same way, so a malformed symbol in a stored value is a DecodingError"
    @Test func decodingAMalformedSymbolIsADecodingError() throws {
        let json = try AssetSymbol(validating: "FRED").toJSON()
        let tampered = json.replacingOccurrences(of: "FRED", with: "FR ED")
        #expect(tampered != json)
        let error = #expect(throws: JSONError.self) {
            let _: AssetSymbol = try tampered.fromJSON()
        }
        #expect(isDecodingError(error))
    }

    // C1: decoding validates the same way: an empty stored symbol is a DecodingError
    @Test func decodingAnEmptySymbolIsADecodingError() throws {
        let json = try AssetSymbol(validating: "FRED").toJSON()
        let tampered = json.replacingOccurrences(of: "FRED", with: "")
        let error = #expect(throws: JSONError.self) {
            let _: AssetSymbol = try tampered.fromJSON()
        }
        #expect(isDecodingError(error))
    }

    // C1: decoding validates the same way: a too-long stored symbol is a DecodingError
    @Test func decodingATooLongSymbolIsADecodingError() throws {
        let json = try AssetSymbol(validating: "FRED").toJSON()
        let tampered = json.replacingOccurrences(of: "FRED", with: "FREDFLINTSTONE")
        let error = #expect(throws: JSONError.self) {
            let _: AssetSymbol = try tampered.fromJSON()
        }
        #expect(isDecodingError(error))
    }

    // C1: decoding validates the same way, and the validation upper-cases
    // UNRATIFIED-CLARIFICATION: "validates the same way" is read as including the upper-casing.
    @Test func decodingALowerCaseStoredSymbolUpperCasesIt() throws {
        let json = try AssetSymbol(validating: "FRED").toJSON()
        let lowered = json.replacingOccurrences(of: "FRED", with: "fred")
        let decoded: AssetSymbol = try lowered.fromJSON()
        #expect(decoded.text == "FRED")
        #expect(try decoded == AssetSymbol(validating: "FRED"))
    }

    // C1: a malformed symbol inside a stored asset is a DecodingError too
    @Test func decodingAnAssetWithAMalformedSymbolIsADecodingError() throws {
        let json = try Fake.fred.toJSON()
        let tampered = json.replacingOccurrences(of: "FRED", with: "FR/ED")
        #expect(tampered != json)
        let error = #expect(throws: JSONError.self) {
            let _: Asset = try tampered.fromJSON()
        }
        #expect(isDecodingError(error))
    }
}
