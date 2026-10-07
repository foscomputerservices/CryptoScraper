// D32 — Across instances: an explicit conversion through the map; and the total across exchanges ("Home").
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.2: "Up is exact. ... Down refuses lost digits. ...
// Only within one asset. `converted(to:)` asks the map first; tether to USDC is `notEquivalent`, whatever their
// decimals." And § 7.3, the owner's "Home": "A total across exchanges counts in the asset's home instance; each side
// converts to it through the map, and the total refuses where digits would be lost."

import CryptoAsset
import Foundation
import Testing

@Suite("D32 Conversion through the map")
struct D32_ConversionTests {
    // Three instances of one stub asset: the home at 2, a finer holding at 4, another at 8.
    private let home = AssetInstance.stub()
    private let atFour = AssetInstance.stub(chainId: "bedrock:43", address: "quarry-42")
    private let atEight = AssetInstance.stub(chainId: "bedrock:44", address: "quarry-42")
    private let unrelated = AssetInstance.stub(address: "slate-42")

    private func registry() throws -> AssetRegistry {
        let fred = try AssetDeclaration(
            asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
            instances: [AssetDeclaration.Instance(instance: home, decimals: 2, symbol: .stub()),
                        AssetDeclaration.Instance(instance: atFour, decimals: 4, symbol: .stub()),
                        AssetDeclaration.Instance(instance: atEight, decimals: 8, symbol: .stub())])
        let barney = try AssetDeclaration(
            asset: .stub(home: unrelated), tokenName: "Barney Coin", symbol: AssetSymbol(validating: "BARNEY"),
            instances: [AssetDeclaration.Instance(instance: unrelated, decimals: 2, symbol: AssetSymbol(validating: "BARNEY"))])
        return try AssetRegistry([fred, barney])
    }

    // "Up is exact." — 2 to 8 multiplies by 10^6
    @Test func upIsExact() throws {
        let converted = try Amount(baseUnits: 123, of: home).converted(to: atEight, in: registry())
        #expect(converted == Amount(baseUnits: 123_000_000, of: atEight))
    }

    // "Down refuses lost digits."
    @Test func downRefusesLostDigits() throws {
        let fine = Amount(baseUnits: 12_345_678, of: atEight)
        let registry = try registry()
        #expect(throws: AmountError.notRepresentable(fine, in: atFour)) { try fine.converted(to: atFour, in: registry) }
    }

    // "down" converts when no digit is lost
    @Test func downConvertsWhenNothingIsLost() throws {
        // 0.12340000 at 8 is 0.1234 at 4, exactly
        #expect(try Amount(baseUnits: 12_340_000, of: atEight).converted(to: atFour, in: registry())
                == Amount(baseUnits: 1_234, of: atFour))
    }

    // "Only within one asset." — notEquivalent whatever the decimals
    @Test func acrossAssetsIsNotEquivalent() throws {
        let registry = try registry()
        #expect(throws: AmountError.notEquivalent(home, unrelated)) {
            try Amount(baseUnits: 1, of: home).converted(to: unrelated, in: registry)
        }
    }

    // "tether to USDC is `notEquivalent`, whatever their decimals" — the library's own two
    @Test func tetherToUSDCIsNotEquivalent() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let tether = EIP155.Ethereum.usdt.instance
        let usdc = EIP155.Ethereum.usdc.instance
        #expect(throws: AmountError.notEquivalent(tether, usdc)) {
            try Amount(baseUnits: 1, of: tether).converted(to: usdc, in: registry)
        }
    }

    // "The same quantity in another instance of the same asset" — to itself it is unchanged
    @Test func toItsOwnInstanceIsUnchanged() throws {
        let amount = Amount(baseUnits: 42, of: atFour)
        #expect(try amount.converted(to: atFour, in: registry()) == amount)
    }

    // "up is exact, down refuses lost digits" — a round trip up then down returns the amount
    @Test func upThenDownReturnsTheAmount() throws {
        let registry = try registry()
        let amount = Amount(baseUnits: 110_134, of: home)
        #expect(try amount.converted(to: atEight, in: registry).converted(to: home, in: registry) == amount)
    }

    // "Home": "each side converts to it through the map" — a total of two holdings in the home instance
    @Test func totalAcrossHoldingsCountsInTheHome() throws {
        let registry = try registry()
        let left = Amount(baseUnits: 11_013_400, of: atFour)       // 1101.3400 at 4
        let right = Amount(baseUnits: 250_000_000, of: atEight)    // 2.50000000 at 8
        let total = try left.converted(to: home, in: registry) + right.converted(to: home, in: registry)
        #expect(total == Amount(baseUnits: 110_384, of: home))
        #expect(total.instance == home)
    }

    // "Home": "the total refuses where digits would be lost"
    @Test func totalRefusesLostDigits() throws {
        let registry = try registry()
        let left = Amount(baseUnits: 11_013_425, of: atFour)       // 1101.3425: digits in the third and fourth place
        #expect(throws: AmountError.notRepresentable(left, in: home)) { try left.converted(to: home, in: registry) }
    }

    // "Across instances, a conversion goes through the equivalence map, exactly or not at all." — negative amounts too
    @Test func negativeConvertsExactlyOrNotAtAll() throws {
        let registry = try registry()
        #expect(try Amount(baseUnits: -12_340_000, of: atEight).converted(to: atFour, in: registry)
                == Amount(baseUnits: -1_234, of: atFour))
        let lossy = Amount(baseUnits: -12_345_678, of: atEight)
        #expect(throws: AmountError.notRepresentable(lossy, in: atFour)) { try lossy.converted(to: atFour, in: registry) }
    }
}
