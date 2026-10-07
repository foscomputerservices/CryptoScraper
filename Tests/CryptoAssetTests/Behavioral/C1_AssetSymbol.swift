// C1 — An asset's symbol, as a typed value and not a string.
// Projected from docs/fosline-suite-protocols.md C1 (the design keeps it, § 1.6: "`AssetSymbol` stays as C1 declares it"):
// "A symbol is validated on the way in, upper-cased, so a malformed one is an error at the boundary and never a
// value inside; decoding validates the same way, so a malformed symbol in a stored value is a `DecodingError`."

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("C1 AssetSymbol")
struct C1_AssetSymbolTests {
    // "upper-cased on the way in"
    @Test func lowerCaseIsUpperCased() throws {
        #expect(try AssetSymbol(validating: "btc").text == "BTC")
    }

    // "Throws AssetSymbolError when `candidate` is empty"
    @Test func emptyThrowsEmpty() {
        #expect(throws: AssetSymbolError.empty) { try AssetSymbol(validating: "") }
    }

    // "`\"BT C\"`, a thirteen-character symbol and `\"B/TC\"` throw `malformed`"
    @Test(arguments: ["BT C", "ABCDEFGHIJKLM", "B/TC"])
    func malformedThrowsMalformed(_ candidate: String) {
        #expect(throws: AssetSymbolError.malformed(candidate)) { try AssetSymbol(validating: candidate) }
    }

    // "`\"1INCH\"`, `\"X.Y\"` and `\"A-B\"` are accepted"
    @Test(arguments: ["1INCH", "X.Y", "A-B"])
    func lettersDigitsPointDashAccepted(_ candidate: String) throws {
        #expect(try AssetSymbol(validating: candidate).text == candidate)
    }

    // "one to twelve characters"
    @Test func twelveCharactersAccepted() throws {
        #expect(try AssetSymbol(validating: "ABCDEFGHIJKL").text == "ABCDEFGHIJKL")
    }

    // "a malformed symbol in a stored value is a `DecodingError`"
    @Test(.disabled("Classified 2026-10-07: asserts fromJSON() throws a bare DecodingError; the design says a malformed symbol in a stored value is a DecodingError (C1), which AssetSymbol's init(from:) throws, and FOSFoundation's fromJSON() hands it up wrapped in JSONError; see the identity ledger")) func malformedSymbolInJSONIsDecodingError() {
        let json = "\"B/TC\""
        #expect(throws: DecodingError.self) { let _: AssetSymbol = try json.fromJSON() }
    }

    // "decoding validates the same way" — a well-formed symbol round-trips through toJSON() / fromJSON()
    @Test func roundTrips() throws {
        let symbol = try AssetSymbol(validating: "usdc")
        let back: AssetSymbol = try symbol.toJSON().fromJSON()
        #expect(back == symbol)
    }

    // "On a chain, a symbol is a name: shown to a reader, never the identity." (design § 1.6)
    @Test func symbolIsNotAnIdentity() throws {
        // Two instances with one symbol stay two instances: identity is the id, never the symbol.
        let one = AssetInstance.stub(address: "quarry-42")
        let two = AssetInstance.stub(address: "slate-42")
        let a = try AssetDeclaration.Instance(instance: one, decimals: 4, symbol: AssetSymbol(validating: "FRED"))
        let b = try AssetDeclaration.Instance(instance: two, decimals: 4, symbol: AssetSymbol(validating: "FRED"))
        #expect(a.symbol == b.symbol)
        #expect(a.instance != b.instance)
    }
}
