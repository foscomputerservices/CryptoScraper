// D34 — The price, amended 2026-10-07: no decimals on the value.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.4: "It carries no decimals ... The value is the
// two instances and `scaled`, nothing else, and that is the stored row. The decimals are read from the statement in two
// places only: `init`, to turn the quote amount into quote units per whole base, and `cost(of:in:)`, to turn the size's
// base units into whole base units. Decoding needs no registry". And the owner's ruling of 2026-10-07: a stored price
// carries no decimals, the arithmetic reads the statement when it runs. And the C5 vectors (§ 8.1 of the protocols).

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("D34 Price")
struct D34_PriceTests {
    private let usd = ISO4217.usd.instance
    private let btc = BIP122.Bitcoin.btc.instance

    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "A price names two instances"
    @Test func namesTwoInstances() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        #expect(mid.quote == usd)
        #expect(mid.base == btc)
    }

    // "Quote base units per whole base unit, times 10^9: the stored number"
    @Test func scaledIsQuoteBaseUnitsPerWholeBaseTimesTenToTheNine() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        #expect(mid.scaled == Int128(6_500_000) * 1_000_000_000)
    }

    // "BTC at `\"65000.00\"` USD: 0.15 BTC costs exactly 9,750.00 USD" (C5 vector)
    @Test func fifteenHundredthsOfABitcoin() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let size = Amount(baseUnits: 15_000_000, of: btc)
        #expect(try mid.cost(of: size, in: registry) == Amount(baseUnits: 975_000, of: usd))
    }

    // "0.4 satoshi per token: 10,000 tokens cost exactly 4,000 satoshis" (C5 vector)
    @Test func subSatoshiPriceIsExact() throws {
        let snek = AssetInstance.stub()
        let snekDeclaration = try AssetDeclaration(
            asset: .stub(home: snek), tokenName: "Snek", symbol: .stub(),
            instances: [AssetDeclaration.Instance(instance: snek, decimals: 0, symbol: .stub())])
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations + [snekDeclaration])
        let fill = try Price(Amount(baseUnits: 4_000, of: btc), per: Amount(whole: 10_000, of: snek, in: registry), in: registry)
        #expect(try fill.cost(of: Amount(baseUnits: 10_000, of: snek), in: registry) == Amount(baseUnits: 4_000, of: btc))
        #expect(!fill.isZero)
    }

    // "The cost of `size` at this price, in the quote asset, rounded toward zero" (C5) — 0.4 satoshi for one token is 0
    @Test func costRoundsTowardZero() throws {
        let snek = AssetInstance.stub()
        let snekDeclaration = try AssetDeclaration(
            asset: .stub(home: snek), tokenName: "Snek", symbol: .stub(),
            instances: [AssetDeclaration.Instance(instance: snek, decimals: 0, symbol: .stub())])
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations + [snekDeclaration])
        let fill = try Price(Amount(baseUnits: 4_000, of: btc), per: Amount(whole: 10_000, of: snek, in: registry), in: registry)
        #expect(try fill.cost(of: Amount(baseUnits: 1, of: snek), in: registry) == Amount(baseUnits: 0, of: btc))
    }

    // "against a registry that lacks the base, `cost` throws `undeclaredInstance` (2026-10-07)"
    // The design's DocC names ``AssetError/undeclaredInstance(_:)``; AssetError declares no such case, AssetRegistryError does.
    @Test func costAgainstARegistryLackingTheBaseThrows() throws {
        let full = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: full), per: btc, in: full)
        let empty = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclaredInstance(btc)) {
            try mid.cost(of: Amount(baseUnits: 15_000_000, of: btc), in: empty)
        }
    }

    // "Precondition: `size.instance` is this price's base"
    @Test func costOfAnotherInstanceTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
            let mid = try Price(Amount(whole: 65_000, of: ISO4217.usd.instance, in: registry),
                                per: BIP122.Bitcoin.btc.instance, in: registry)
            _ = try mid.cost(of: Amount(baseUnits: 1, of: EIP155.Ethereum.eth.instance), in: registry)
        }
    }

    // "a ladder of five steps at 5 basis points orders by `<`"
    @Test func ladderOrdersByLessThan() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        var ladder = [mid]
        for _ in 1...5 { ladder.append(ladder.last! * (.one + Fraction(basisPoints: 5))) }
        #expect(ladder == ladder.sorted())
        #expect(ladder.max() == ladder.last)
    }

    // "`spread(to:)` of ask over mid is the step"
    @Test func spreadOfAskOverMidIsTheStep() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let ask = mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.spread(to: mid) == Fraction(basisPoints: 5))
        #expect(mid.spread(to: ask).isNegative)
    }

    // "`Price(_:per size:)` with a zero size traps"
    @Test func perZeroSizeTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
            _ = try Price(Amount(baseUnits: 1, of: ISO4217.usd.instance),
                          per: Amount.zero(of: BIP122.Bitcoin.btc.instance), in: registry)
        }
    }

    // "Precondition: both prices share a base and a quote asset" on `<`
    @Test func lessThanAcrossBasesTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
            let usd = ISO4217.usd.instance
            let a = try Price(Amount(whole: 1, of: usd, in: registry), per: BIP122.Bitcoin.btc.instance, in: registry)
            let b = try Price(Amount(whole: 1, of: usd, in: registry), per: EIP155.Ethereum.eth.instance, in: registry)
            _ = a < b
        }
    }

    // "public var isZero"
    @Test func zeroPriceIsZero() throws {
        let registry = try registry()
        let nothing = try Price(Amount.zero(of: usd), per: btc, in: registry)
        #expect(nothing.isZero)
    }

    // "Decoding needs no registry because nothing decoded depends on the decimals"
    @Test func roundTripsWithNoRegistry() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let back: Price = try mid.toJSON().fromJSON()
        #expect(back == mid)
        #expect(back.scaled == mid.scaled)
    }

    // "they are needed only when the price meets an amount, and then the one static statement answers"
    @Test func aDecodedPriceCostsAgainstTheStatement() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let back: Price = try mid.toJSON().fromJSON()
        #expect(try back.cost(of: Amount(baseUnits: 15_000_000, of: btc), in: registry) == Amount(baseUnits: 975_000, of: usd))
    }

    // "init, to turn the quote amount into quote units per whole base" — per a size equals per a whole base
    @Test func perSizeAgreesWithPerBase() throws {
        let registry = try registry()
        let perWhole = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let perSize = try Price(Amount(baseUnits: 975_000, of: usd), per: Amount(baseUnits: 15_000_000, of: btc), in: registry)
        #expect(perSize == perWhole)
    }

    // "the decimals are read from the statement ... at `init`" — an undeclared base at init throws
    @Test func perSizeOfAnUndeclaredBaseThrows() throws {
        let empty = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclaredInstance(btc)) {
            try Price(Amount(baseUnits: 975_000, of: usd), per: Amount(baseUnits: 15_000_000, of: btc), in: empty)
        }
    }

    // "Walks a step of the ladder; rounds toward zero" (C5) — the step keeps both instances
    @Test func stepKeepsBothInstances() throws {
        let registry = try registry()
        let mid = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        let ask = mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.quote == usd)
        #expect(ask.base == btc)
    }
}
