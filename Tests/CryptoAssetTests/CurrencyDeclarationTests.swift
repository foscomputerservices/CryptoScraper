// CurrencyDeclarationTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

// The unit of account is the currency (the owner's ruling of 2026-10-09, Road C): a stream names `iso4217:USD`, and the
// feed and the exchange each name their own holding for it from a declaration of which holdings stand for which
// currency. A holding is accepted where the currency is named, one for one, with no conversion and no rate.

@Suite("Which holdings stand for a currency")
struct CurrencyDeclarationTests {
    static let euro = Fixtures.instance("iso4217:EUR")

    static func registry() throws -> AssetRegistry {
        let registry = Fixtures.registryWithHoldings()
        try registry.add([Fixtures.declaration(euro, decimals: 2, symbol: "EUR")])
        return registry
    }

    @Test func theOneHoldingOnAnExchangeThatStandsForTheDollarIsFoundByTheCurrencyAndTheChain() throws {
        let registry = try Self.registry()
        try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC, Fixtures.binanceUSDT])])
        #expect(try registry.holding(standingFor: Fixtures.usd, on: "exchange:hyperliquid") == Fixtures.hyperliquidUSDC)
        #expect(try registry.holding(standingFor: Fixtures.usd, on: "exchange:binance") == Fixtures.binanceUSDT)
    }

    @Test func theCurrencyAHoldingStandsForIsFoundByTheHolding() throws {
        let registry = try Self.registry()
        try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC])])
        #expect(try registry.currency(of: Fixtures.hyperliquidUSDC) == Fixtures.usd)
    }

    @Test func standingForACurrencyLeavesTheHoldingsAssetAndDecimalsAsDeclared() throws {
        let registry = try Self.registry()
        try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC])])
        #expect(try registry.asset(of: Fixtures.hyperliquidUSDC) == .usdc)
        #expect(try registry.decimals(of: Fixtures.hyperliquidUSDC) == 6)
        #expect(try registry.decimals(of: Fixtures.usd) == 2)
        #expect(try !registry.isEquivalent(Fixtures.hyperliquidUSDC, Fixtures.usd), "no conversion: two assets still")
    }

    @Test func aChainWhereNoHoldingStandsForTheCurrencyIsATypedRefusal() throws {
        let registry = try Self.registry()
        try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC])])
        #expect(throws: AssetRegistryError.noHoldingStandsFor(Fixtures.usd, on: "exchange:kraken")) {
            try registry.holding(standingFor: Fixtures.usd, on: "exchange:kraken")
        }
        #expect(throws: AssetRegistryError.noHoldingStandsFor(Self.euro, on: "exchange:hyperliquid")) {
            try registry.holding(standingFor: Self.euro, on: "exchange:hyperliquid")
        }
    }

    @Test func twoHoldingsOnOneChainStandingForTheCurrencyAreAFindingNamingThemNeverAPick() throws {
        let registry = try Self.registry()
        try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.krakenUSD, Fixtures.krakenXBT])])
        #expect(throws: AssetRegistryError.holdingsStandFor(Fixtures.usd, on: "exchange:kraken", [Fixtures.krakenUSD, Fixtures.krakenXBT])) {
            try registry.holding(standingFor: Fixtures.usd, on: "exchange:kraken")
        }
        // Each still names its currency.
        #expect(try registry.currency(of: Fixtures.krakenUSD) == Fixtures.usd)
        #expect(try registry.currency(of: Fixtures.krakenXBT) == Fixtures.usd)
    }

    @Test func aHoldingThatStandsForNoCurrencyIsATypedRefusal() throws {
        let registry = try Self.registry()
        #expect(throws: AssetRegistryError.standsForNoCurrency(Fixtures.binanceUSDT)) {
            try registry.currency(of: Fixtures.binanceUSDT)
        }
    }

    @Test func onlyAnISO4217InstanceIsACurrency() throws {
        let registry = try Self.registry()
        #expect(throws: AssetRegistryError.notACurrency(Fixtures.usdc)) {
            try registry.add([CurrencyDeclaration(currency: Fixtures.usdc, holdings: [Fixtures.hyperliquidUSDC])])
        }
    }

    @Test func anUndeclaredHoldingOrCurrencyIsRefusedAndNothingIsAdded() throws {
        let registry = try Self.registry()
        let stranger = Fixtures.instance("exchange:hyperliquid:FRED")
        #expect(throws: AssetRegistryError.undeclaredInstance(stranger)) {
            try registry.add([CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC, stranger])])
        }
        #expect(throws: AssetRegistryError.standsForNoCurrency(Fixtures.hyperliquidUSDC), "the declaration was refused whole") {
            try registry.currency(of: Fixtures.hyperliquidUSDC)
        }
        let yen = Fixtures.instance("iso4217:JPY")
        #expect(throws: AssetRegistryError.undeclaredInstance(yen)) {
            try registry.add([CurrencyDeclaration(currency: yen, holdings: [Fixtures.hyperliquidUSDC])])
        }
    }

    @Test func aHoldingStandsForOneCurrencyAtMostAndDeclaringAgainAddsNothing() throws {
        let registry = try Self.registry()
        let dollar = CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC])
        try registry.add([dollar])
        try registry.add([dollar])
        #expect(try registry.holding(standingFor: Fixtures.usd, on: "exchange:hyperliquid") == Fixtures.hyperliquidUSDC)
        #expect(throws: AssetRegistryError.standsForTwoCurrencies(Fixtures.hyperliquidUSDC)) {
            try registry.add([CurrencyDeclaration(currency: Self.euro, holdings: [Fixtures.hyperliquidUSDC])])
        }
        #expect(try registry.currency(of: Fixtures.hyperliquidUSDC) == Fixtures.usd)
    }

    @Test func aDeclarationEncodesAsItsTwoInstancesIds() throws {
        let declaration = CurrencyDeclaration(currency: Fixtures.usd, holdings: [Fixtures.hyperliquidUSDC, Fixtures.binanceUSDT])
        let stored: CurrencyDeclaration = try declaration.toJSON().fromJSON()
        #expect(stored == declaration)
        #expect(try declaration.toJSON().contains("\"exchange:hyperliquid:USDC\""))
        #expect(CurrencyDeclaration.stub().currency == ISO4217.usd.instance)
    }
}
