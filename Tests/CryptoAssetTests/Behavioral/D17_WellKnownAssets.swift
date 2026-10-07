// D17 — The well-known assets and their holdings.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.7: "The five stay ... now as classes, each built
// from the generated constants of § 2.7, never from a literal: `Asset.usdc`'s home is `EIP155.Ethereum.usdc`,
// `Asset.btc`'s is `BIP122.Bitcoin.btc`, `Asset.usd`'s is `ISO4217.usd`. The comment strings above are what those
// constants hold." And § 5.2: "Their decimals stay: USD 2, USDC 6, USDT 6, BTC 8, ETH 18 at their homes".

import CryptoAsset
import Foundation
import Testing

@Suite("D17 The five well-known assets")
struct D17_WellKnownAssetsTests {
    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "`Asset.usdc`'s home is `EIP155.Ethereum.usdc`"
    @Test func usdcHomeIsGenerated() {
        #expect(Asset.usdc.id == EIP155.Ethereum.usdc.instance.id)
    }

    // "`Asset.btc`'s is `BIP122.Bitcoin.btc`"
    @Test func btcHomeIsGenerated() {
        #expect(Asset.btc.id == BIP122.Bitcoin.btc.instance.id)
    }

    // "`Asset.usd`'s is `ISO4217.usd`"
    @Test func usdHomeIsGenerated() {
        #expect(Asset.usd.id == ISO4217.usd.instance.id)
    }

    // "static let usdt: Asset   // \"eip155:1:0xdac17f958d2ee523a2206206994597c13d831ec7\""
    @Test func usdtHomeIsGenerated() {
        #expect(Asset.usdt.id == EIP155.Ethereum.usdt.instance.id)
    }

    // "static let eth: Asset    // \"eip155:1:eth\""
    @Test func ethHomeIsGenerated() {
        #expect(Asset.eth.id == EIP155.Ethereum.eth.instance.id)
    }

    // "The comment strings above are what those constants hold." — each literal as the design writes it
    @Test func theFiveHoldTheDocumentsStrings() {
        #expect(Asset.usd.id == "iso4217:USD")
        #expect(Asset.usdc.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(Asset.usdt.id == "eip155:1:0xdac17f958d2ee523a2206206994597c13d831ec7")
        #expect(Asset.btc.id == "bip122:000000000019d6689c085ae165831e93:btc")
        #expect(Asset.eth.id == "eip155:1:eth")
    }

    // "Their decimals stay: USD 2, USDC 6, USDT 6, BTC 8, ETH 18 at their homes"
    @Test func homeDecimalsStay() throws {
        let registry = try registry()
        #expect(try registry.decimals(of: ISO4217.usd.instance) == 2)
        #expect(try registry.decimals(of: EIP155.Ethereum.usdc.instance) == 6)
        #expect(try registry.decimals(of: EIP155.Ethereum.usdt.instance) == 6)
        #expect(try registry.decimals(of: BIP122.Bitcoin.btc.instance) == 8)
        #expect(try registry.decimals(of: EIP155.Ethereum.eth.instance) == 18)
    }

    // "Holds the library's own declarations from the start" (§ 2.3) — each of the five is declared
    @Test(arguments: [Asset.usd, .usdc, .usdt, .btc, .eth])
    func eachIsALibraryDeclaration(_ asset: Asset) throws {
        #expect(AssetRegistry.libraryDeclarations.contains { $0.asset == asset })
        #expect(try registry().declaration(of: asset).asset == asset)
    }

    // "each with its unit names, so cent and dollar, satoshi and bitcoin, wei, gwei and ether are declared once" (C2, kept)
    @Test func unitNamesAreDeclaredOnce() throws {
        let registry = try registry()
        #expect(try registry.declaration(of: .usd).unit(named: "cent")?.exponent == 0)
        #expect(try registry.declaration(of: .usd).unit(named: "dollar")?.exponent == 2)
        #expect(try registry.declaration(of: .btc).unit(named: "satoshi")?.exponent == 0)
        #expect(try registry.declaration(of: .btc).unit(named: "bitcoin")?.exponent == 8)
        #expect(try registry.declaration(of: .eth).unit(named: "wei")?.exponent == 0)
        #expect(try registry.declaration(of: .eth).unit(named: "gwei")?.exponent == 9)
        #expect(try registry.declaration(of: .eth).unit(named: "ether")?.exponent == 18)
    }

    // "the assets a stream settles in": each home is its declaration's first instance ("its home first", § 2.1)
    @Test(arguments: [Asset.usd, .usdc, .usdt, .btc, .eth])
    func homeIsFirst(_ asset: Asset) throws {
        #expect(try registry().declaration(of: asset).instances.first?.instance.id == asset.id)
    }
}
