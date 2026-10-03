// R4_ComparableWithinOneAsset.swift
//
// R4: comparable only within one currency; `<` returning false across currencies makes max, sorted and
// ==-based logic silently wrong. C3: "Comparison traps on two assets instead of returning false".
// The trap itself is in C6_BoundaryRule.swift.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Amount ordering — R4, C3 behavioral")
struct R4_ComparableWithinOneAssetTests {

    // R4: within one asset, < orders by quantity
    @Test func aSmallerAmountIsLess() {
        #expect(Amount(baseUnits: 41, asset: Fake.fred) < Amount(baseUnits: 42, asset: Fake.fred))
        #expect((Amount(baseUnits: 42, asset: Fake.fred) < Amount(baseUnits: 41, asset: Fake.fred)) == false)
    }

    // R4: an amount is not less than itself
    @Test func anAmountIsNotLessThanItself() {
        let amount = Amount(baseUnits: 42, asset: Fake.fred)
        #expect((amount < amount) == false)
    }

    // R4: negative amounts order below zero
    @Test func aNegativeAmountIsLessThanZero() {
        #expect(Amount(baseUnits: -42, asset: Fake.fred) < Amount.zero(of: Fake.fred))
    }

    // R4: sorted orders amounts of one asset by quantity
    @Test func sortedOrdersAmountsOfOneAsset() {
        let amounts = [
            Amount(baseUnits: 42, asset: Fake.fred),
            Amount(baseUnits: -42, asset: Fake.fred),
            Amount(baseUnits: 0, asset: Fake.fred),
            Amount(baseUnits: 41, asset: Fake.fred),
        ]
        #expect(amounts.sorted().map(\.baseUnits) == [-42, 0, 41, 42])
    }

    // R4: max and min pick by quantity within one asset
    @Test func maxAndMinPickWithinOneAsset() {
        let amounts = [
            Amount(baseUnits: 42, asset: Fake.fred),
            Amount(baseUnits: -42, asset: Fake.fred),
            Amount(baseUnits: 7, asset: Fake.fred),
        ]
        #expect(amounts.max()?.baseUnits == 42)
        #expect(amounts.min()?.baseUnits == -42)
    }

    // R4: ordering beyond Int64 is exact
    @Test func orderingBeyondInt64IsExact() {
        let a = Amount(baseUnits: pow10(30), asset: Fake.bedrock)
        let b = Amount(baseUnits: pow10(30) + 1, asset: Fake.bedrock)
        #expect(a < b)
    }

    // R4 with C2: a named and an unnamed declaration of one asset compare without trapping
    @Test func aNamedAndAnUnnamedDeclarationCompare() {
        #expect(Amount(baseUnits: 41, asset: Fake.fred) < Amount(baseUnits: 42, asset: Fake.fredNamed))
    }
}
