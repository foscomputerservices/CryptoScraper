// R10_ValueConformances.swift
//
// R10: Sendable, Hashable, Equatable on every value type; R2: the quantity is a native Int128.
// C1–C8 declare Codable, Hashable, Sendable and Stubbable on every value, Comparable on Amount, Fraction and
// Price, and Error, Hashable, Sendable on the errors. These tests compile only when the conformances exist;
// each also exercises one behavior the conformance promises.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

private func isValue<T: Codable & Hashable & Sendable & Stubbable>(_: T.Type) -> Bool { true }
private func isOrderedValue<T: Codable & Hashable & Comparable & Sendable & Stubbable>(_: T.Type) -> Bool { true }
private func isError<T: Error & Hashable & Sendable>(_: T.Type) -> Bool { true }

@Suite("Value conformances — R10, R2 behavioral")
struct R10_ValueConformancesTests {

    // R10, C1, C2, C8: the values are Codable, Hashable, Sendable and Stubbable
    @Test func everyValueIsCodableHashableSendableAndStubbable() {
        #expect(isValue(AssetSymbol.self))
        #expect(isValue(Asset.self))
        #expect(isValue(Asset.Unit.self))
        #expect(isValue(Asset.UnitDescription.self))
        #expect(isValue(BarInterval.self))
    }

    // R10, C3, C4, C5: the three quantities are Comparable too
    @Test func theQuantitiesAreComparable() {
        #expect(isOrderedValue(Amount.self))
        #expect(isOrderedValue(Fraction.self))
        #expect(isOrderedValue(Price.self))
    }

    // C1, C2, C6: the errors are Hashable and Sendable errors
    @Test func theErrorsAreHashableSendableErrors() {
        #expect(isError(AssetSymbolError.self))
        #expect(isError(AssetError.self))
        #expect(isError(AmountError.self))
    }

    // R2: "a signed Int128 quantity in base units"
    @Test func theQuantityIsASignedInt128() {
        let baseUnits: Int128 = Amount(baseUnits: -42, asset: Fake.fred).baseUnits
        #expect(baseUnits == -42)
    }

    // R10: values cross a concurrency boundary intact
    @Test func valuesCrossATaskBoundary() async {
        let amount = Amount(baseUnits: 42, asset: Fake.barney)
        let price = Price(Amount(whole: 42, of: Fake.fred), per: Fake.barney)
        let (a, p) = await Task.detached { (amount, price) }.value
        #expect(a == amount)
        #expect(p == price)
    }

    // C6: errors with equal cases compare equal, so a caller can match them
    @Test func errorsCompareByCaseAndValue() throws {
        let fred = try AssetSymbol(validating: "FRED")
        let dino = try AssetSymbol(validating: "DINO")
        #expect(AmountError.assetConflict(fred, dino) == AmountError.assetConflict(fred, dino))
        #expect(AmountError.assetConflict(fred, dino) != AmountError.assetConflict(dino, fred))
        #expect(AssetError.unitExponentOutOfRange(31) != AssetError.unitExponentOutOfRange(-1))
        #expect(AssetSymbolError.empty != AssetSymbolError.malformed("FRED FLINTSTONE"))
    }
}
