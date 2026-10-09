// ExchangeCurrencyDeclarationsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// The unit of account is the currency (the owner's ruling of 2026-10-09, Road C): each exchange chain declares, beside
// its holdings and at its client's init, which of them stand for the dollar. Nothing is asked of an exchange: each client
// is made over a session that is never called, in a registry of the library's declarations alone.

@Suite("The exchanges' holdings that stand for the dollar")
struct ExchangeCurrencyDeclarationsTests {
    static let dollar = ISO4217.usd.instance

    static func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    static var unanswered: ReplaySession {
        ReplaySession { _, _ in preconditionFailure("no request is made at a client's init") }
    }

    @Test func hyperliquidsUSDCStandsForTheDollar() throws {
        let registry = try Self.registry()
        _ = HyperliquidOHLCVClient(session: Self.unanswered, registry: registry)
        let usdc = AssetInstance(HyperliquidHolding.usdc)
        #expect(try registry.holding(standingFor: Self.dollar, on: HyperliquidExchangeChain.default.id) == usdc)
        #expect(try registry.currency(of: usdc) == Self.dollar)
        #expect(try registry.asset(of: usdc) == .usdc, "it stays USD Coin's instance")
    }

    @Test func krakensDollarStandsForTheDollar() throws {
        let registry = try Self.registry()
        _ = KrakenOHLCVClient(session: Self.unanswered, registry: registry)
        let usd = AssetInstance(KrakenHolding.usd)
        #expect(try registry.holding(standingFor: Self.dollar, on: KrakenExchangeChain.default.id) == usd)
        #expect(try registry.currency(of: usd) == Self.dollar)
    }

    @Test func coinbasesDollarStandsForTheDollar() throws {
        let registry = try Self.registry()
        _ = CoinbaseOHLCVClient(session: Self.unanswered, registry: registry)
        let usd = AssetInstance(CoinbaseHolding.usd)
        #expect(try registry.holding(standingFor: Self.dollar, on: CoinbaseExchangeChain.default.id) == usd)
        #expect(try registry.currency(of: usd) == Self.dollar)
    }

    @Test func binancesTetherAndItsUSDCBothStandForTheDollarSoTheChainAloneNamesNeither() throws {
        let registry = try Self.registry()
        _ = BinanceOHLCVClient(session: Self.unanswered, registry: registry)
        let usdt = AssetInstance(BinanceHolding.usdt)
        let usdc = AssetInstance(BinanceHolding.usdc)
        #expect(try registry.currency(of: usdt) == Self.dollar)
        #expect(try registry.currency(of: usdc) == Self.dollar)
        #expect(try registry.decimals(of: usdc) == 8)
        #expect(throws: AssetRegistryError.holdingsStandFor(Self.dollar, on: BinanceExchangeChain.default.id, [usdc, usdt])) {
            try registry.holding(standingFor: Self.dollar, on: BinanceExchangeChain.default.id)
        }
    }

    @Test func aChainWhoseClientWasNotMadeHasNoHoldingForTheDollar() throws {
        let registry = try Self.registry()
        _ = HyperliquidOHLCVClient(session: Self.unanswered, registry: registry)
        #expect(throws: AssetRegistryError.noHoldingStandsFor(Self.dollar, on: KrakenExchangeChain.default.id)) {
            try registry.holding(standingFor: Self.dollar, on: KrakenExchangeChain.default.id)
        }
    }

    @Test func aBTCHoldingStandsForNoCurrency() throws {
        let registry = try Self.registry()
        _ = HyperliquidOHLCVClient(session: Self.unanswered, registry: registry)
        let btc = AssetInstance(HyperliquidHolding.btc)
        #expect(throws: AssetRegistryError.standsForNoCurrency(btc)) {
            try registry.currency(of: btc)
        }
    }
}
