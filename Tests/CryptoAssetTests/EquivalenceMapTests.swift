// EquivalenceMapTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// Design § 6, "The equivalence map", and the registry of § 2.3: an asset is the class of its instances, an instance
// is one asset's, a declared instance's decimals never change, and a miss is a typed error.

@Suite("The equivalence map")
struct EquivalenceMapTests {
    @Test func binanceAtEightAndTheChainAtSixAreTwoInstancesOfOneClass() throws {
        let registry = Fixtures.registryWithHoldings()
        #expect(try registry.asset(of: Fixtures.binanceUSDT) == .usdt)
        #expect(try registry.asset(of: Fixtures.usdt) == .usdt)
        #expect(try registry.isEquivalent(Fixtures.binanceUSDT, Fixtures.usdt))
        #expect(try registry.decimals(of: Fixtures.binanceUSDT) == 8)
        #expect(try registry.decimals(of: Fixtures.usdt) == 6)
    }

    @Test func threeChainsOneClass() throws {
        let registry = Fixtures.registryWithHoldings()
        for instance in [Fixtures.usdc, Fixtures.bscUSDC, Fixtures.polygonUSDC] {
            #expect(try registry.asset(of: instance) == .usdc)
        }
        #expect(try registry.instance(of: .usdc, on: "eip155:137") == Fixtures.polygonUSDC)
    }

    @Test func twoUnrelatedDeclaredInstancesAreNotEquivalent() throws {
        let registry = Fixtures.registryWithHoldings()
        #expect(try !registry.isEquivalent(Fixtures.binanceUSDT, Fixtures.hyperliquidUSDC))
    }

    @Test func anUndeclaredInstanceIsATypedErrorNeverAFalse() {
        let registry = Fixtures.registryWithHoldings()
        let undeclared = Fixtures.instance("eip155:1:0x0000000000000000000000000000000000000042")
        #expect(throws: AssetRegistryError.undeclaredInstance(undeclared)) {
            try registry.isEquivalent(undeclared, Fixtures.usdc)
        }
    }

    @Test func krakensXBTIsTheInstancesSymbolAndBitcoinIsItsClass() throws {
        let registry = Fixtures.registryWithHoldings()
        #expect(try registry.asset(of: Fixtures.krakenXBT) == .btc)
        #expect(try registry.decimals(of: Fixtures.krakenXBT) == 10)
        #expect(try registry.instance(of: .btc, on: "exchange:kraken") == Fixtures.krakenXBT)
        let xbt = try registry.declaration(of: .btc).instances.first { $0.instance == Fixtures.krakenXBT }
        #expect(xbt?.symbol.text == "XBT")
        #expect(try registry.declaration(of: .btc).symbol.text == "BTC")
    }

    @Test func anAccountIsAnAddressNotAnInstance() {
        let registry = Fixtures.registryWithHoldings()
        let account = Fixtures.instance("exchange:hyperliquid:four-hour-2x")
        #expect(throws: AssetRegistryError.undeclaredInstance(account)) {
            try registry.asset(of: account)
        }
    }

    @Test func noInstanceOnAChainIsATypedError() {
        let registry = Fixtures.registryWithHoldings()
        #expect(throws: AssetRegistryError.noInstance(.eth, on: "exchange:kraken")) {
            try registry.instance(of: .eth, on: "exchange:kraken")
        }
    }

    @Test func anUndeclaredAssetIsATypedError() throws {
        let registry = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclared(.btc)) {
            try registry.declaration(of: .btc)
        }
    }

    @Test func oneAssetPerInstance() throws {
        let registry = Fixtures.registryWithHoldings()
        let other = AssetDeclaration.stub(instances: [.stub(), Fixtures.holding(Fixtures.binanceUSDT, decimals: 8, symbol: "USDT")])
        #expect(throws: AssetRegistryError.instanceInTwoAssets(Fixtures.binanceUSDT)) {
            try registry.add([other])
        }
        // nothing of the refused add was kept
        #expect(throws: AssetRegistryError.undeclared(.stub())) {
            try registry.declaration(of: .stub())
        }
        #expect(try registry.asset(of: Fixtures.binanceUSDT) == .usdt)
    }

    @Test func decimalsNeverChange() throws {
        let registry = Fixtures.registryWithHoldings()
        let refresh = Fixtures.libraryDeclaration(of: .btc, adding: [Fixtures.holding(Fixtures.krakenXBT, decimals: 8, symbol: "XBT")])
        #expect(throws: AssetRegistryError.decimalsChanged(Fixtures.krakenXBT)) {
            try registry.replace([refresh])
        }
        #expect(try registry.decimals(of: Fixtures.krakenXBT) == 10)
    }

    @Test func anAddThatRestatesADeclaredInstancesDecimalsIsRefused() throws {
        let registry = Fixtures.registryWithHoldings()
        let restated = Fixtures.libraryDeclaration(of: .btc, adding: [Fixtures.holding(Fixtures.krakenXBT, decimals: 8, symbol: "XBT")])
        #expect(throws: AssetRegistryError.decimalsChanged(Fixtures.krakenXBT)) {
            try registry.add([restated])
        }
    }

    @Test func aRefreshReplacesADeclarationThatIsNotTheLibrarys() throws {
        let registry = Fixtures.registryWithHoldings()
        let refresh = Fixtures.libraryDeclaration(of: .btc, adding: [Fixtures.holding(Fixtures.krakenXBT, decimals: 10, symbol: "XBT")])
        try registry.replace([refresh])
        #expect(try registry.declaration(of: .btc) == refresh)
        #expect(throws: AssetRegistryError.undeclaredInstance(Fixtures.hyperliquidBTC)) {
            try registry.asset(of: Fixtures.hyperliquidBTC)
        }
    }

    @Test func aRefreshNeverReplacesALibraryDeclaration() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(throws: AssetRegistryError.libraryDeclaration(.usd)) {
            try registry.replace([Fixtures.libraryDeclaration(of: .usd)])
        }
    }

    @Test func anAddToADeclaredAssetAddsItsNewInstances() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        try registry.add([Fixtures.libraryDeclaration(of: .btc, adding: [Fixtures.holding(Fixtures.krakenXBT, decimals: 10, symbol: "XBT")])])
        #expect(try registry.asset(of: Fixtures.krakenXBT) == .btc)
        #expect(try registry.decimals(of: Fixtures.btc) == 8)
        #expect(try registry.declaration(of: .btc).instances.map(\.instance) == [Fixtures.btc, Fixtures.krakenXBT])
    }

    @Test func anAddThatDescribesADeclaredAssetOtherwiseConflicts() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let renamed = try AssetDeclaration(asset: .btc, tokenName: "Not Bitcoin", symbol: AssetSymbol(validating: "BTC"),
                                           instances: Fixtures.libraryDeclaration(of: .btc).instances)
        #expect(throws: AssetRegistryError.conflictingDeclaration(.btc)) {
            try registry.add([renamed])
        }
    }

    @Test func theSharedRegistryHoldsTheLibrarysDeclarations() throws {
        for declaration in AssetRegistry.libraryDeclarations {
            #expect(try AssetRegistry.shared.declaration(of: declaration.asset) == declaration)
        }
        #expect(try AssetRegistry.shared.decimals(of: Fixtures.eth) == 18)
    }
}
