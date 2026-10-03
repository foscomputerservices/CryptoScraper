// C6_BoundaryRule.swift
//
// C6: the boundary validates and the inside trusts. Two values just arrived from two sources are combined
// with the throwing pair, which refuses two assets; inside, the operators assume one asset and trap on two.
// R3: "a mismatch of currencies is a programmer error (precondition or a thrown error), never a silent result".
// R4: comparison across currencies is the same programmer error.
//
// Each trap is paired with a passing sibling that builds the same values, in this file or in C3, C4, C5.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("The boundary rule — C6, R3, R4 behavioral")
struct C6_BoundaryRuleTests {

    // MARK: The throwing pair

    // C6: adding(_:) of one asset is the sum
    @Test func addingTwoAmountsOfOneAssetGivesTheSum() throws {
        let ours = Amount(baseUnits: 42, asset: Fake.fred)
        let theirs = Amount(baseUnits: -84, asset: Fake.fred)
        #expect(try ours.adding(theirs) == ours + theirs)
        #expect(try ours.adding(theirs).baseUnits == -42)
    }

    // C6: subtracting(_:) of one asset is the difference
    @Test func subtractingTwoAmountsOfOneAssetGivesTheDifference() throws {
        let ours = Amount(baseUnits: 42, asset: Fake.fred)
        let theirs = Amount(baseUnits: 84, asset: Fake.fred)
        #expect(try ours.subtracting(theirs).baseUnits == -42)
    }

    // C6, C2: a named and an unnamed declaration of one asset pass the throwing pair
    @Test func theThrowingPairAcceptsANamedAndAnUnnamedDeclaration() throws {
        let ours = Amount(baseUnits: 42, asset: Fake.fredNamed)
        let theirs = Amount(baseUnits: 42, asset: Fake.fred)
        #expect(try ours.adding(theirs).baseUnits == 84)
        #expect(try ours.subtracting(theirs).isZero)
    }

    // C6: "catch AmountError.assetConflict(let ours, let theirs)": adding two assets throws, ours first
    @Test func addingTwoAssetsThrowsAnAssetConflict() {
        let ours = Amount(baseUnits: 42, asset: Fake.fred)
        let theirs = Amount(baseUnits: 42, asset: Fake.barney)
        #expect(throws: AmountError.assetConflict(Fake.fred.symbol, Fake.barney.symbol)) {
            try ours.adding(theirs)
        }
    }

    // C6: subtracting two assets throws, ours first
    @Test func subtractingTwoAssetsThrowsAnAssetConflict() {
        let ours = Amount(baseUnits: 42, asset: Fake.barney)
        let theirs = Amount(baseUnits: 42, asset: Fake.fred)
        #expect(throws: AmountError.assetConflict(Fake.barney.symbol, Fake.fred.symbol)) {
            try ours.subtracting(theirs)
        }
    }

    // C6 with C2's identity: one symbol at two exponents is two assets, so the pair refuses them
    // Gap: assetConflict carries two symbols, which are equal here; the case is asserted, its values are not.
    @Test func theThrowingPairRefusesOneSymbolAtTwoExponents() {
        let ours = Amount(baseUnits: 42, asset: Fake.fred)
        let theirs = Amount(baseUnits: 42, asset: Fake.fredAtEight)
        #expect(throws: AmountError.self) {
            try ours.adding(theirs)
        }
        #expect(throws: AmountError.self) {
            try ours.subtracting(theirs)
        }
    }

    // C6: a refused combination is never a silent result: zero amounts of two assets are refused too
    @Test func addingZerosOfTwoAssetsIsStillAConflict() {
        #expect(throws: AmountError.assetConflict(Fake.fred.symbol, Fake.dino.symbol)) {
            try Amount.zero(of: Fake.fred).adding(.zero(of: Fake.dino))
        }
    }

    // MARK: Inside, the operators trap on two assets

    #if os(macOS) || os(Linux) || os(Windows)

    // C3, R3: "+ Precondition: both amounts are of one asset"
    @Test func plusOnTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 42, asset: Fake.fred) + Amount(baseUnits: 42, asset: Fake.barney)
        }
    }

    // C3, R3: "- Precondition: both amounts are of one asset"
    @Test func minusOnTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 42, asset: Fake.fred) - Amount(baseUnits: 42, asset: Fake.barney)
        }
    }

    // C3, R3: one symbol at two exponents is two assets, so + traps
    @Test func plusOnOneSymbolAtTwoExponentsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 42, asset: Fake.fred) + Amount(baseUnits: 42, asset: Fake.fredAtEight)
        }
    }

    // C3, R4: "< Precondition: both amounts are of one asset"; "Comparison traps on two assets instead of
    // returning false"
    @Test func lessThanOnTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 41, asset: Fake.fred) < Amount(baseUnits: 42, asset: Fake.barney)
        }
    }

    // R4: sorted over two assets traps rather than ordering silently
    @Test func sortingAmountsOfTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = [Amount(baseUnits: 42, asset: Fake.fred), Amount(baseUnits: 41, asset: Fake.barney)].sorted()
        }
    }

    // R4: max over two assets traps rather than picking silently
    @Test func maxOfAmountsOfTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = [Amount(baseUnits: 42, asset: Fake.fred), Amount(baseUnits: 41, asset: Fake.barney)].max()
        }
    }

    // C3: "count(in:) Precondition: unit is one of the asset's units"
    @Test func readingInAUnitNotTheAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(whole: 42, of: Fake.slate).count(in: Asset.Unit(name: "boulder", exponent: 19))
        }
    }

    // C3: "/ Precondition: rhs is not zero"
    @Test func dividingAnAmountByAZeroFractionTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 42, asset: Fake.fred) / Fraction.zero
        }
    }

    // C4: "init(_:over:) Precondition: both amounts are of one asset"
    @Test func aFractionOfTwoAssetsTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 21, asset: Fake.fred), over: Amount(baseUnits: 42, asset: Fake.barney))
        }
    }

    // C4: "init(_:over:) Precondition: whole is not zero"
    @Test func aFractionOverZeroTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 21, asset: Fake.fred), over: .zero(of: Fake.fred))
        }
    }

    // C5: "init(_:per size:) Precondition: size is positive": zero
    @Test func aPricePerAZeroSizeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 42, of: Fake.fred), per: Amount.zero(of: Fake.barney))
        }
    }

    // C5: "init(_:per size:) Precondition: size is positive": negative
    @Test func aPricePerANegativeSizeTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 42, of: Fake.fred), per: Amount(whole: -2, of: Fake.barney))
        }
    }

    // C5: "cost(of:) Precondition: size.asset is this price's base asset"
    @Test func theCostOfASizeInAnotherAssetTraps() async {
        await #expect(processExitsWith: .failure) {
            let price = Price(Amount(whole: 42, of: Fake.fred), per: Fake.barney)
            _ = price.cost(of: Amount(whole: 1, of: Fake.dino))
        }
    }

    // C5: the cost of a size in the quote asset (not the base) traps
    @Test func theCostOfASizeInTheQuoteAssetTraps() async {
        await #expect(processExitsWith: .failure) {
            let price = Price(Amount(whole: 42, of: Fake.fred), per: Fake.barney)
            _ = price.cost(of: Amount(whole: 1, of: Fake.fred))
        }
    }

    // C5: "< Precondition: both prices share a base and a quote asset": two bases
    @Test func comparingPricesOfTwoBasesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 41, of: Fake.fred), per: Fake.barney)
                < Price(Amount(whole: 42, of: Fake.fred), per: Fake.slate)
        }
    }

    // C5: "< Precondition: both prices share a base and a quote asset": two quotes
    @Test func comparingPricesOfTwoQuotesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 41, of: Fake.fred), per: Fake.barney)
                < Price(Amount(whole: 42, of: Fake.dino), per: Fake.barney)
        }
    }

    // C5: "spread(to:) Precondition: both prices share a base and a quote asset": two bases
    @Test func theSpreadBetweenPricesOfTwoBasesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 41, of: Fake.fred), per: Fake.barney)
                .spread(to: Price(Amount(whole: 42, of: Fake.fred), per: Fake.slate))
        }
    }

    // C5: "spread(to:) Precondition: both prices share a base and a quote asset": two quotes
    @Test func theSpreadBetweenPricesOfTwoQuotesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Price(Amount(whole: 41, of: Fake.fred), per: Fake.barney)
                .spread(to: Price(Amount(whole: 42, of: Fake.dino), per: Fake.barney))
        }
    }

    #endif
}
