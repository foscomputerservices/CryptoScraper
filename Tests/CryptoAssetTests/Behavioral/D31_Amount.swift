// D31 — The amount carries its instance and nothing else.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.1: "An exact quantity counted in one instance's
// base units ... Carries its instance and its count, nothing else; its decimals are the statement's. Two amounts add
// only within one instance." And "Only `init(whole:)`, the named units and `converted(to:)` look the statement up.
// `init(baseUnits:of:)` does not". And § 6: "The C3 vectors stand within one instance."

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("D31 Amount")
struct D31_AmountTests {
    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "`Amount(whole: 100, of: usdc).baseUnits == 100_000_000`" (C3 vector, within one instance)
    @Test func hundredUSDCIsAHundredMillionBaseUnits() throws {
        let amount = try Amount(whole: 100, of: EIP155.Ethereum.usdc.instance, in: registry())
        #expect(amount.baseUnits == 100_000_000)
        #expect(amount.instance == EIP155.Ethereum.usdc.instance)
    }

    // "A whole number of whole units, at the instance's decimals" — the same whole at two instances of one asset
    @Test func wholeReadsEachInstancesDecimals() throws {
        let home = AssetInstance.stub()
        let away = AssetInstance.stub(chainId: "bedrock:43", address: "quarry-42")
        let declaration = try AssetDeclaration(
            asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
            instances: [AssetDeclaration.Instance(instance: home, decimals: 6, symbol: .stub()),
                        AssetDeclaration.Instance(instance: away, decimals: 8, symbol: .stub())])
        let registry = try AssetRegistry([declaration])
        #expect(try Amount(whole: 1, of: home, in: registry).baseUnits == 1_000_000)
        #expect(try Amount(whole: 1, of: away, in: registry).baseUnits == 100_000_000)
    }

    // "`Amount(whole:of:)` gains a `try`" (§ 5.1) — an undeclared instance throws
    @Test func wholeOfAnUndeclaredInstanceThrows() throws {
        let registry = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclaredInstance(.stub())) {
            try Amount(whole: 1, of: .stub(), in: registry)
        }
    }

    // "`init(baseUnits:of:)` does not [look the statement up]: it is how a client's decode and a stored row make an amount"
    @Test func baseUnitsNeedsNoRegistry() {
        let amount = Amount(baseUnits: 2_500, of: .stub())
        #expect(amount.baseUnits == 2_500)
        #expect(amount.instance == .stub())
    }

    // "`Amount(count: 12_500, in: satoshi, of: btc).count(in: satoshi) == (12_500, 0)`"
    @Test func satoshiCountRoundTrips() throws {
        let registry = try registry()
        let satoshi = try #require(try registry.declaration(of: .btc).unit(named: "satoshi"))
        let amount = try Amount(count: 12_500, in: satoshi, of: BIP122.Bitcoin.btc.instance, in: registry)
        let read = try amount.count(in: satoshi, in: registry)
        #expect(read.count == 12_500)
        #expect(read.remainder == 0)
    }

    // "`Amount(count: 5, in: gwei, of: eth).baseUnits == 5_000_000_000`"
    @Test func fiveGweiIsFiveBillionWei() throws {
        let registry = try registry()
        let gwei = try #require(try registry.declaration(of: .eth).unit(named: "gwei"))
        let tip = try Amount(count: 5, in: gwei, of: EIP155.Ethereum.eth.instance, in: registry)
        #expect(tip.baseUnits == 5_000_000_000)
    }

    // "`count(in:)` on a quantity not a whole number of the unit returns the remainder"
    @Test func countReturnsTheRemainder() throws {
        let registry = try registry()
        let gwei = try #require(try registry.declaration(of: .eth).unit(named: "gwei"))
        let amount = Amount(baseUnits: 5_000_000_007, of: EIP155.Ethereum.eth.instance)
        let read = try amount.count(in: gwei, in: registry)
        #expect(read.count == 5)
        #expect(read.remainder == 7)
    }

    // "a unit not the asset's throws `unitOutOfRange`"
    @Test func aUnitNotTheAssetsThrows() throws {
        let registry = try registry()
        let gwei = try #require(try registry.declaration(of: .eth).unit(named: "gwei"))
        #expect(throws: AssetError.unitOutOfRange(gwei)) {
            try Amount(count: 1, in: gwei, of: ISO4217.usd.instance, in: registry)
        }
    }

    // "`+`, `-` exact at `Int128.max - 1`"
    @Test func plusAndMinusExactAtTheExtreme() {
        let one = Amount(baseUnits: 1, of: .stub())
        let nearMax = Amount(baseUnits: Int128.max - 1, of: .stub())
        #expect((nearMax + one).baseUnits == Int128.max)
        #expect((Amount(baseUnits: Int128.max, of: .stub()) - one).baseUnits == Int128.max - 1)
    }

    // "`* Fraction(percent: 50)` on an odd positive quantity rounds toward zero"
    @Test func halfOfAnOddPositiveRoundsTowardZero() {
        #expect((Amount(baseUnits: 7, of: .stub()) * Fraction(percent: 50)).baseUnits == 3)
    }

    // "and on an odd negative quantity rounds toward zero, not down"
    @Test func halfOfAnOddNegativeRoundsTowardZero() {
        #expect((Amount(baseUnits: -7, of: .stub()) * Fraction(percent: 50)).baseUnits == -3)
    }

    // "`/ Fraction` likewise"
    @Test func divisionRoundsTowardZero() {
        #expect((Amount(baseUnits: 7, of: .stub()) / Fraction(integer: 2)).baseUnits == 3)
        #expect((Amount(baseUnits: -7, of: .stub()) / Fraction(integer: 2)).baseUnits == -3)
    }

    // "`/ Fraction.zero` traps"
    @Test func divisionByZeroTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 7, of: .stub()) / Fraction.zero
        }
    }

    // "a full-width vector, 10^30 base units times a fraction at scale 10^9, is exact and does not trap"
    @Test func fullWidthScalingIsExact() {
        let big = Int128(1_000_000_000_000_000) * Int128(1_000_000_000_000_000)   // 10^30
        let amount = Amount(baseUnits: big, of: .stub())
        #expect((amount * Fraction(percent: 50)).baseUnits == big / 2)
    }

    // "public static prefix func -", "isNegative", "zero(of:)", "isZero"
    @Test func negationZeroAndSign() {
        let amount = Amount(baseUnits: 42, of: .stub())
        #expect((-amount).baseUnits == -42)
        #expect((-amount).isNegative)
        #expect(!amount.isNegative)
        #expect(Amount.zero(of: .stub()).isZero)
        #expect(Amount.zero(of: .stub()).instance == .stub())
        #expect((amount - amount) == Amount.zero(of: .stub()))
    }

    // "Comparable" within one instance
    @Test func comparesWithinOneInstance() {
        #expect(Amount(baseUnits: 1, of: .stub()) < Amount(baseUnits: 2, of: .stub()))
        #expect([Amount(baseUnits: 3, of: .stub()), Amount(baseUnits: 1, of: .stub())].max()?.baseUnits == 3)
    }

    // "No exponent and no exchange on the value." — two amounts with one instance and one count are equal, nothing else compared
    @Test func equalityIsInstanceAndCount() {
        #expect(Amount(baseUnits: 42, of: .stub()) == Amount(baseUnits: 42, of: .stub()))
        #expect(Amount(baseUnits: 42, of: .stub()) != Amount(baseUnits: 43, of: .stub()))
    }

    // "Two amounts add only within one instance" — the sum keeps the instance
    @Test func sumKeepsTheInstance() {
        let sum = Amount(baseUnits: 40, of: .stub()) + Amount(baseUnits: 2, of: .stub())
        #expect(sum.instance == .stub())
        #expect(sum.baseUnits == 42)
    }
}
