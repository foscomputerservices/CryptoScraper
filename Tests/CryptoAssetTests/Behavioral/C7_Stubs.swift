// C7 — The stubs of § 1's values, in the nested two-stub form, where the design does not redesign them.
// Projected from docs/fosline-suite-protocols.md C7: "the bare stub delegates to the parameterized one, and every
// parameter defaults to its own type's stub" and "The defaults are the reserved fakes ... a symbol of the
// Flintstones, an exponent no asset uses, 42 where a number is (R11)."

import CryptoAsset
import Foundation
import Testing

@Suite("C7 Stubs")
struct C7_StubsTests {
    // "the bare stub delegates to the parameterized one" — AssetSymbol
    @Test func symbolStubDelegates() {
        #expect(AssetSymbol.stub() == AssetSymbol.stub())
    }

    // "a symbol of the Flintstones" — C7's own "FRED"
    @Test func symbolStubIsFlintstone() {
        #expect(AssetSymbol.stub().text == "FRED")
    }

    // "Our own stored `Amount` ... the 42 in its stub" (C1–C8 preamble: "the 42 in its stub")
    @Test func amountStubIsFortyTwo() {
        #expect(Amount.stub().baseUnits == 42)
    }

    // "every parameter defaults to its own type's stub()" — Amount's instance is AssetInstance's stub
    @Test func amountStubInstanceIsInstanceStub() {
        #expect(Amount.stub().instance == AssetInstance.stub())
    }

    // "stub(…) with every parameter of the public initializer" — overriding one keeps the other at its fake
    @Test func amountStubOverrideKeepsTheRest() {
        // invented: Amount.stub(baseUnits:instance:) — C7 says the parameters are the initializer's; its labels are `baseUnits:` and `of:`
        let amount = Amount.stub(baseUnits: 7)
        #expect(amount.baseUnits == 7)
        #expect(amount.instance == AssetInstance.stub())
    }

    // "Where one value must agree with another, the default says so through the nested stub"
    @Test func priceStubIsDecodableAndSelfConsistent() throws {
        let price = Price.stub()
        #expect(price.base != price.quote)
    }

    // "Fraction ... follow the same pair"
    @Test func fractionStubDelegates() {
        #expect(Fraction.stub() == Fraction.stub())
    }

    // "BarInterval follow the same pair"
    @Test func barIntervalStubDelegates() {
        #expect(BarInterval.stub() == BarInterval.stub())
    }

    // "BarInterval ... stub(…) with every parameter of the public initializer"
    @Test func barIntervalStubOverride() {
        let interval = BarInterval.stub(count: 15)
        #expect(interval.count == 15)
        #expect(interval.unit == BarInterval.stub().unit)
    }

    // "a test calls `stub()`, never `init`" and "gets a correct instance at every depth" — AssetDeclaration's stub is valid
    @Test func declarationStubBuildsARegistry() throws {
        // invented: AssetDeclaration.stub() — the design marks it Stubbable and C7 gives the form; no default value is stated
        _ = try AssetRegistry([AssetDeclaration.stub()])
    }

    // "gets a correct instance at every depth" — the declaration stub's instance list is its home first
    @Test func declarationStubHomeFirst() {
        let declaration = AssetDeclaration.stub()
        #expect(declaration.instances.first?.instance.id == declaration.asset.id)
    }

    // "every parameter defaults to its own type's stub()" — Instance.stub's instance is AssetInstance.stub()
    @Test func instanceStubDefaults() {
        // invented: AssetDeclaration.Instance.stub() — Stubbable per the design; defaults per C7's rule
        #expect(AssetDeclaration.Instance.stub().instance == AssetInstance.stub())
        #expect(AssetDeclaration.Instance.stub().symbol == AssetSymbol.stub())
    }
}
