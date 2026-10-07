// D26 — Equivalence: the map restored as the structure, at the registry.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.6: "An asset is one entry of your map. Its
// instances are its contracts on chains and its holdings on exchanges." and "Nothing is hacked in. There is no special
// case for USDC or for any one contract. Every amount is counted in its exchange holding, and the map is the only path
// from one instance to another." And § 6 "Three chains, one class: USDC on Ethereum, BNB Smart Chain and Polygon give
// one `asset(of:)`".

import CryptoAsset
import Foundation
import Testing

@Suite("D26 Equivalence at the registry")
struct D26_RegistryEquivalenceTests {
    // "Three chains, one class: USDC on Ethereum, BNB Smart Chain and Polygon give one `asset(of:)`"
    @Test(.disabled("Classified 2026-10-07: needs USDC on BNB Smart Chain (EIP155.BinanceSmartChain's usdc), not declared: CoinGecko's usd-coin lists no binance-smart-chain contract (the recorded coin-usd-coin.json), so the importer generated none; see the identity ledger")) func usdcOnThreeChainsIsOneAsset() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(try registry.asset(of: EIP155.Ethereum.usdc.instance) == .usdc)
        #expect(try registry.asset(of: EIP155.Polygon.usdc.instance) == .usdc)
        // invented: EIP155.BNBSmartChain.usdc — § 2.7 shows Ethereum and Polygon only; BNB Smart Chain's enum name is not declared
        #expect(try registry.asset(of: EIP155.BNBSmartChain.usdc.instance) == .usdc)
    }

    // "Whether two instances are one asset" — cross-chain
    @Test func usdcOnEthereumAndPolygonAreEquivalent() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(try registry.isEquivalent(EIP155.Ethereum.usdc.instance, EIP155.Polygon.usdc.instance))
    }

    // "Only within one asset. ... tether to USDC is `notEquivalent`, whatever their decimals."
    @Test func tetherAndUSDCAreNotEquivalent() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(try !registry.isEquivalent(EIP155.Ethereum.usdt.instance, EIP155.Ethereum.usdc.instance))
    }

    // "The class's key is its home instance's id: ... the issuing chain's contract for a token"
    @Test func usdCoinsKeyIsItsEthereumContract() {
        #expect(Assets.usdCoin.asset.id == EIP155.Ethereum.usdc.instance.id)
    }

    // "The class's key is its home instance's id: the native chain's main contract for a native coin"
    @Test func bitcoinsKeyIsItsNativeCoin() {
        #expect(Assets.bitcoin.asset.id == BIP122.Bitcoin.btc.instance.id)
    }

    // "The class's key is its home instance's id: ... `iso4217:` for a fiat"
    @Test func usdsKeyIsTheFiat() {
        #expect(Asset.usd.id == ISO4217.usd.instance.id)
        #expect(ISO4217.usd.instance.chainId == nil)
    }

    // "The key counts nothing and moves nothing." — the two instances keep their own decimals in one class
    @Test func oneClassKeepsEachInstancesDecimals() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(try registry.decimals(of: EIP155.Ethereum.usdc.instance) == EIP155.Ethereum.usdc.decimals)
        #expect(try registry.decimals(of: EIP155.Polygon.usdc.instance) == EIP155.Polygon.usdc.decimals)
    }

    // "The instance of `asset` on the chain or exchange `chainId`" — the map answers across chains
    @Test func instanceOfUSDCOnPolygon() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(try registry.instance(of: .usdc, on: EIP155.Polygon.chainId) == EIP155.Polygon.usdc.instance)
    }

    // "Wrapped tokens and an asset's kind: still OQ-C4's. WBTC is its own asset, not an instance of BTC." (§ 7.2)
    @Test func ethereumsCoinIsNotBitcoin() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(try !registry.isEquivalent(EIP155.Ethereum.eth.instance, BIP122.Bitcoin.btc.instance))
    }
}
