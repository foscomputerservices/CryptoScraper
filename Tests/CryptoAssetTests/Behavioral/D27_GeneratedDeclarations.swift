// D27 — The generated declarations.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.7: "One file per CAIP namespace in CryptoAsset,
// generated, the only place an address or an id is written. A top-level enum for the namespace, a nested enum per chain
// carrying its CAIP-2 id, and the chain's contracts as constants on it, each a declared instance with its decimals and
// symbol." And "The registry's `shared` is filled from the generated declarations at start ... No network is touched to
// know an identity."

import CryptoAsset
import Foundation
import Testing

@Suite("D27 Generated declarations")
struct D27_GeneratedDeclarationsTests {
    // "public static let namespace = \"eip155\""
    @Test func eip155Namespace() {
        #expect(EIP155.namespace == "eip155")
    }

    // "public static let chainId = \"eip155:1\""
    @Test func ethereumChainId() {
        #expect(EIP155.Ethereum.chainId == "eip155:1")
    }

    // "public static let chainId = \"eip155:137\""
    @Test func polygonChainId() {
        #expect(EIP155.Polygon.chainId == "eip155:137")
    }

    // "a nested enum per chain carrying its CAIP-2 id" — each chain's id is in its namespace
    @Test func chainIdsAreInTheirNamespace() {
        #expect(EIP155.Ethereum.chainId.hasPrefix(EIP155.namespace + ":"))
        #expect(EIP155.Polygon.chainId.hasPrefix(EIP155.namespace + ":"))
    }

    // "public static let usdc: AssetDeclaration.Instance    // 0xa0b8…, 6, \"USDC\""
    @Test func ethereumUSDC() {
        #expect(EIP155.Ethereum.usdc.decimals == 6)
        #expect(EIP155.Ethereum.usdc.symbol.text == "USDC")
        #expect(EIP155.Ethereum.usdc.instance.chainId == EIP155.Ethereum.chainId)
        #expect(EIP155.Ethereum.usdc.instance.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
    }

    // "public static let usdt: AssetDeclaration.Instance    // 0xdac1…, 6, \"USDT\""
    @Test func ethereumUSDT() {
        #expect(EIP155.Ethereum.usdt.decimals == 6)
        #expect(EIP155.Ethereum.usdt.symbol.text == "USDT")
        #expect(EIP155.Ethereum.usdt.instance.id == "eip155:1:0xdac17f958d2ee523a2206206994597c13d831ec7")
    }

    // "public static let eth: AssetDeclaration.Instance     // the native coin, 18"
    @Test func ethereumEth() {
        #expect(EIP155.Ethereum.eth.decimals == 18)
        #expect(EIP155.Ethereum.eth.instance.id == "eip155:1:eth")
    }

    // "public enum Polygon { ... public static let usdc: AssetDeclaration.Instance }"
    @Test func polygonUSDCIsOnPolygon() {
        #expect(EIP155.Polygon.usdc.instance.chainId == EIP155.Polygon.chainId)
        #expect(EIP155.Polygon.usdc.instance != EIP155.Ethereum.usdc.instance)
    }

    // "`Asset.btc`'s is `BIP122.Bitcoin.btc`" (§ 1.7) and "\"bip122:000000000019d6689c085ae165831e93:btc\""
    @Test func bitcoinBTC() {
        #expect(BIP122.Bitcoin.btc.instance.id == "bip122:000000000019d6689c085ae165831e93:btc")
        #expect(BIP122.Bitcoin.btc.decimals == 8)
    }

    // "the projector's brief: BIP122.Bitcoin.chainId" — a nested enum per chain carrying its CAIP-2 id
    @Test func bitcoinChainId() {
        // invented: BIP122.Bitcoin.chainId — the shape of § 2.7 applied to bip122; only EIP155's is written out
        #expect(BIP122.Bitcoin.chainId == "bip122:000000000019d6689c085ae165831e93")
    }

    // "`Asset.usd`'s is `ISO4217.usd`" and "\"iso4217:USD\""
    @Test func iso4217USD() {
        #expect(ISO4217.usd.instance.id == "iso4217:USD")
        #expect(ISO4217.usd.decimals == 2)
    }

    // the brief's `EXCHANGE.Kraken.chainId`; § 1.3 "`exchange:binance`, `exchange:coinbase`, `exchange:hyperliquid`, `exchange:kraken`"
    @Test func exchangeNamespaceChainIds() {
        // invented: EXCHANGE.Kraken / .Binance / .Coinbase / .Hyperliquid — named in the projector's brief; not declared in the design's code
        #expect(EXCHANGE.Kraken.chainId == "exchange:kraken")
        #expect(EXCHANGE.Binance.chainId == "exchange:binance")
        #expect(EXCHANGE.Coinbase.chainId == "exchange:coinbase")
        #expect(EXCHANGE.Hyperliquid.chainId == "exchange:hyperliquid")
    }

    // "public static let usdCoin = AssetDeclaration(home: EIP155.Ethereum.usdc, instances: [EIP155.Polygon.usdc, …])"
    @Test func usdCoinsHomeIsFirst() {
        #expect(Assets.usdCoin.instances.first == EIP155.Ethereum.usdc)
        #expect(Assets.usdCoin.instances.contains(EIP155.Polygon.usdc))
    }

    // "The Swift name of a constant comes from the reference's stable id, not its symbol: CoinGecko's `usd-coin` becomes `usdCoin`."
    @Test func usdCoinsReferenceIdIsUsdCoin() {
        #expect(Assets.usdCoin.aggregatorId == "usd-coin")
        #expect(Assets.usdCoin.asset == .usdc)
    }

    // "`KrakenHolding.xbt` is in `Assets.bitcoin`" (§ 4.1) — the generated bitcoin class is Asset.btc
    @Test func bitcoinClassIsBTC() {
        #expect(Assets.bitcoin.asset == .btc)
        #expect(Assets.bitcoin.instances.first == BIP122.Bitcoin.btc)
    }

    // "each a declared instance with its decimals and symbol" — every generated constant is a valid declared instance
    @Test func generatedConstantsBuildARegistry() throws {
        let registry = try AssetRegistry([Assets.usdCoin, Assets.bitcoin])
        #expect(try registry.decimals(of: EIP155.Polygon.usdc.instance) == EIP155.Polygon.usdc.decimals)
    }

    // "The registry's `shared` is filled from the generated declarations at start"
    @Test func sharedHoldsTheGeneratedClasses() throws {
        #expect(try AssetRegistry.shared.declaration(of: Assets.usdCoin.asset).instances.contains(EIP155.Polygon.usdc))
        #expect(try AssetRegistry.shared.asset(of: EIP155.Polygon.usdc.instance) == .usdc)
    }

    // "the only place an address or an id is written" — an id from a generated constant validates as an identity
    @Test func generatedIdsValidate() throws {
        for constant in [EIP155.Ethereum.usdc, EIP155.Ethereum.usdt, EIP155.Ethereum.eth, EIP155.Polygon.usdc,
                         BIP122.Bitcoin.btc, ISO4217.usd] {
            #expect(try AssetInstance(validating: constant.instance.id) == constant.instance)
        }
    }
}
