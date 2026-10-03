// ConflictsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

@Suite("Conflicts")
struct ConflictsTests {
    @Test func equalityAcrossAssetsIsFalseAndDoesNotTrap() {
        #expect(Amount(baseUnits: 1, asset: .usd) != Amount(baseUnits: 1, asset: .btc))
        #expect(Amount.zero(of: .usdc) != Amount.zero(of: .usdt))
    }

    @Test func lessThanTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, asset: .usd) < Amount(baseUnits: 2, asset: .btc)
        }
    }

    @Test func plusTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, asset: .usd) + Amount(baseUnits: 2, asset: .btc)
        }
    }

    @Test func minusTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, asset: .usd) - Amount(baseUnits: 2, asset: .btc)
        }
    }

    @Test func fractionOverTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Fraction(Amount(baseUnits: 1, asset: .usd), over: Amount(baseUnits: 2, asset: .btc))
        }
    }

    @Test func costTraps() async {
        await #expect(processExitsWith: .failure) {
            let mid = Price(Amount(whole: 65_000, of: .usd), per: .btc)
            _ = mid.cost(of: Amount(whole: 1, of: .eth))
        }
    }

    @Test func priceLessThanTraps() async {
        await #expect(processExitsWith: .failure) {
            let btc = Price(Amount(whole: 65_000, of: .usd), per: .btc)
            let eth = Price(Amount(whole: 2_500, of: .usd), per: .eth)
            _ = btc < eth
        }
    }

    @Test func priceLessThanTrapsOnTheQuote() async {
        await #expect(processExitsWith: .failure) {
            let usd = Price(Amount(whole: 65_000, of: .usd), per: .btc)
            let usdc = Price(Amount(whole: 65_000, of: .usdc), per: .btc)
            _ = usd < usdc
        }
    }

    @Test func spreadTraps() async {
        await #expect(processExitsWith: .failure) {
            let btc = Price(Amount(whole: 65_000, of: .usd), per: .btc)
            let eth = Price(Amount(whole: 2_500, of: .usd), per: .eth)
            _ = btc.spread(to: eth)
        }
    }

    @Test func addingThrowsCarryingBothSymbols() throws {
        let ours = Amount(whole: 1, of: .usdc)
        let theirs = Amount(whole: 1, of: .usdt)
        do {
            _ = try ours.adding(theirs)
            Issue.record("adding(_:) did not throw")
        } catch AmountError.assetConflict(let first, let second) {
            #expect(first.text == "USDC")
            #expect(second.text == "USDT")
        }
    }

    @Test func subtractingThrowsCarryingBothSymbols() {
        #expect(throws: AmountError.assetConflict(Asset.usdt.symbol, Asset.usdc.symbol)) {
            try Amount(whole: 1, of: .usdt).subtracting(Amount(whole: 1, of: .usdc))
        }
    }

    @Test func theThrowingPairAgreesWithTheOperatorsOnOneAsset() throws {
        let a = Amount(baseUnits: 7, asset: .usdc)
        let b = Amount(baseUnits: 3, asset: .usdc)
        #expect(try a.adding(b) == a + b)
        #expect(try a.subtracting(b) == a - b)
    }
}
