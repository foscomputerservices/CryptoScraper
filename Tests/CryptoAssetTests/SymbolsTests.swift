// SymbolsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Symbols")
struct SymbolsTests {
    @Test func upperCasedOnTheWayIn() throws {
        #expect(try AssetSymbol(validating: "btc").text == "BTC")
        #expect(try AssetSymbol(validating: "btc") == AssetSymbol(validating: "BTC"))
    }

    @Test func emptyThrowsEmpty() {
        #expect(throws: AssetSymbolError.empty) {
            try AssetSymbol(validating: "")
        }
    }

    @Test(arguments: ["BT C", "ABCDEFGHIJKLM", "B/TC"])
    func malformedThrowsMalformed(candidate: String) {
        #expect(throws: AssetSymbolError.malformed(candidate)) {
            try AssetSymbol(validating: candidate)
        }
    }

    @Test(arguments: ["1INCH", "X.Y", "A-B", "ABCDEFGHIJKL", "B"])
    func wellFormedIsAccepted(candidate: String) throws {
        #expect(try AssetSymbol(validating: candidate).text == candidate)
    }

    @Test func anAssetFromAStringValidatesItsSymbol() {
        #expect(throws: AssetSymbolError.malformed("B/TC")) {
            try Asset(symbol: "B/TC", unitExponent: 8)
        }
    }
}
