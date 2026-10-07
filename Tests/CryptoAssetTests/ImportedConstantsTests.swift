// ImportedConstantsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// Design § 2.7 and § 2.2: the importer's generated constants replace the hand-written ones; each keeps the address,
// the decimals and the symbol the hand-written constant held, and the well-known assets are built from them.

@Suite("The imported constants")
struct ImportedConstantsTests {
    @Test func usdCoinOnEthereumIsTheContractTheHandWrittenUSDCWas() {
        #expect(EIP155.Ethereum.usdCoin.instance.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(EIP155.Ethereum.usdCoin.decimals == 6)
        #expect(EIP155.Ethereum.usdCoin.symbol.text == "USDC")
        #expect(EIP155.Ethereum.usdc == EIP155.Ethereum.usdCoin)
    }

    @Test func tetherOnEthereumIsTheContractTheHandWrittenUSDTWas() {
        #expect(EIP155.Ethereum.tether.instance.id == "eip155:1:0xdac17f958d2ee523a2206206994597c13d831ec7")
        #expect(EIP155.Ethereum.tether.decimals == 6)
        #expect(EIP155.Ethereum.tether.symbol.text == "USDT")
        #expect(EIP155.Ethereum.usdt == EIP155.Ethereum.tether)
    }

    @Test func assetsUSDCoinIsTheClassAssetUSDCIs() throws {
        #expect(Assets.usdCoin.asset == .usdc)
        #expect(Assets.usdCoin.instances.first == EIP155.Ethereum.usdCoin)
        #expect(try AssetRegistry.shared.asset(of: EIP155.Ethereum.usdCoin.instance) == .usdc)
    }

    @Test func assetsTetherIsTheClassAssetUSDTIs() throws {
        #expect(Assets.tether.asset == .usdt)
        #expect(Assets.tether.instances.first == EIP155.Ethereum.tether)
        #expect(try AssetRegistry.shared.asset(of: EIP155.Ethereum.tether.instance) == .usdt)
    }

    // Step 8c: one statement, no duplicate. USD Coin's and Tether's declarations are the generated ones, and the shared
    // registry holds them, and every other generated declaration, from the start.

    @Test func theSharedRegistryHoldsUSDCoinsGeneratedInstancesFromTheStart() throws {
        #expect(Asset.usdc == Assets.usdCoin.asset)
        #expect(Assets.usdCoin.instances.first == EIP155.Ethereum.usdCoin)
        #expect(EIP155.Ethereum.usdc == EIP155.Ethereum.usdCoin)
        for instance in Assets.usdCoin.instances {
            #expect(try AssetRegistry.shared.asset(of: instance.instance) == .usdc)
            #expect(try AssetRegistry.shared.decimals(of: instance.instance) == instance.decimals)
        }
        #expect(try AssetRegistry.shared.declaration(of: .usdc).tokenName == Assets.usdCoin.tokenName)
    }

    @Test func theSharedRegistryHoldsEveryGeneratedDeclarationFromTheStart() throws {
        #expect(Assets.all.map(\.aggregatorId) == ["tether", "usd-coin", "pepe"])
        for declaration in Assets.all {
            let shared = try AssetRegistry.shared.declaration(of: declaration.asset)
            #expect(Array(shared.instances.prefix(declaration.instances.count)) == declaration.instances)
            #expect(shared.tokenName == declaration.tokenName && shared.aggregatorId == declaration.aggregatorId)
        }
    }

    @Test func theNativesStayTheConformersAndTheirClassesAreUnchanged() {
        #expect(Asset.btc == (try? Asset(validating: "bip122:000000000019d6689c085ae165831e93:btc")))
        #expect(Asset.eth == (try? Asset(validating: "eip155:1:eth")))
    }
}
