// ConflictsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Conflicts")
struct ConflictsTests {
    @Test func equalityAcrossInstancesIsFalseAndDoesNotTrap() {
        #expect(Amount(baseUnits: 1, of: Fixtures.usd) != Amount(baseUnits: 1, of: Fixtures.btc))
        #expect(Amount.zero(of: Fixtures.usdc) != Amount.zero(of: Fixtures.usdt))
    }

    @Test func lessThanTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: Fixtures.usd) < Amount(baseUnits: 2, of: Fixtures.btc)
        }
    }

    @Test func plusTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: Fixtures.usd) + Amount(baseUnits: 2, of: Fixtures.btc)
        }
    }

    @Test func minusTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: Fixtures.usd) - Amount(baseUnits: 2, of: Fixtures.btc)
        }
    }

    @Test func fractionOverTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 1, of: Fixtures.usd), over: Amount(baseUnits: 2, of: Fixtures.btc))
        }
    }

    @Test func costTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = Fixtures.registry()
            let mid = try! Price(Amount(whole: 65_000, of: Fixtures.usd, in: registry), per: Fixtures.btc, in: registry)
            _ = try! mid.cost(of: Amount(whole: 1, of: Fixtures.eth, in: registry), in: registry)
        }
    }

    @Test func priceLessThanTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = Fixtures.registry()
            let btc = try! Price(Amount(whole: 65_000, of: Fixtures.usd, in: registry), per: Fixtures.btc, in: registry)
            let eth = try! Price(Amount(whole: 2_500, of: Fixtures.usd, in: registry), per: Fixtures.eth, in: registry)
            _ = btc < eth
        }
    }

    @Test func priceLessThanTrapsOnTheQuote() async {
        await #expect(processExitsWith: .failure) {
            let registry = Fixtures.registry()
            let usd = try! Price(Amount(whole: 65_000, of: Fixtures.usd, in: registry), per: Fixtures.btc, in: registry)
            let usdc = try! Price(Amount(whole: 65_000, of: Fixtures.usdc, in: registry), per: Fixtures.btc, in: registry)
            _ = usd < usdc
        }
    }

    @Test func spreadTraps() async {
        await #expect(processExitsWith: .failure) {
            let registry = Fixtures.registry()
            let btc = try! Price(Amount(whole: 65_000, of: Fixtures.usd, in: registry), per: Fixtures.btc, in: registry)
            let eth = try! Price(Amount(whole: 2_500, of: Fixtures.usd, in: registry), per: Fixtures.eth, in: registry)
            _ = btc.spread(to: eth)
        }
    }

    @Test func addingThrowsCarryingBothInstances() throws {
        let ours = Amount(baseUnits: 1, of: Fixtures.usdc)
        let theirs = Amount(baseUnits: 1, of: Fixtures.usdt)
        do {
            _ = try ours.adding(theirs)
            Issue.record("adding(_:) did not throw")
        } catch AmountError.instanceConflict(let first, let second) {
            #expect(first == Fixtures.usdc)
            #expect(second == Fixtures.usdt)
        }
    }

    @Test func subtractingThrowsCarryingBothInstances() {
        #expect(throws: AmountError.instanceConflict(Fixtures.usdt, Fixtures.usdc)) {
            try Amount(baseUnits: 1, of: Fixtures.usdt).subtracting(Amount(baseUnits: 1, of: Fixtures.usdc))
        }
    }

    @Test func theThrowingPairAgreesWithTheOperatorsOnOneInstance() throws {
        let a = Amount(baseUnits: 7, of: Fixtures.usdc)
        let b = Amount(baseUnits: 3, of: Fixtures.usdc)
        #expect(try a.adding(b) == a + b)
        #expect(try a.subtracting(b) == a - b)
    }
}
