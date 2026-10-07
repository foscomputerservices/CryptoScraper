// D21 — The instances of the day, on the exchanges.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.1: "`exchange:binance:USDT` at 8, beside
// `eip155:1:0xdac1…` at 6, one asset. `exchange:kraken:USD` at 4, beside `iso4217:USD` at 2. `exchange:kraken:XBT` at 10,
// symbol \"XBT\", beside `bip122:…:btc` at 8. `exchange:hyperliquid:BTC` at 5". And § 1.7: "Their exchange holdings are
// library declarations beside them". And § 6's exchange-chain and equivalence-map bullets.

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D21 Exchange instances")
struct D21_ExchangeInstancesTests {
    private let binanceUSDT = AssetInstance(BinanceHolding.usdt)
    private let krakenUSD = AssetInstance(KrakenHolding.usd)
    private let krakenXBT = AssetInstance(KrakenHolding.xbt)

    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "Binance at 8 and the chain at 6 as two instances of one class"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func binanceTetherAndEthereumTetherAreOneAsset() throws {
        let registry = try registry()
        #expect(try registry.asset(of: binanceUSDT) == registry.asset(of: EIP155.Ethereum.usdt.instance))
        #expect(try registry.isEquivalent(binanceUSDT, EIP155.Ethereum.usdt.instance))
    }

    // "and their decimals stay 8 and 6"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func binanceTetherKeepsEightEthereumSix() throws {
        let registry = try registry()
        #expect(try registry.decimals(of: binanceUSDT) == 8)
        #expect(try registry.decimals(of: EIP155.Ethereum.usdt.instance) == 6)
    }

    // "`exchange:kraken:USD` at 4, beside `iso4217:USD` at 2"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenDollarAtFourIsTheDollar() throws {
        let registry = try registry()
        #expect(try registry.decimals(of: krakenUSD) == 4)
        #expect(try registry.asset(of: krakenUSD) == .usd)
    }

    // "Kraken's recorded Assets answer yields `exchange:kraken:XBT` at 10 and `exchange:kraken:USD` at 4, each declared."
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenBitcoinAtTen() throws {
        #expect(try registry().decimals(of: krakenXBT) == 10)
    }

    // "Kraken's XBT as the instance's symbol: `exchange:kraken:XBT`'s symbol is \"XBT\", and `registry.asset(of:)` of it is `.btc`."
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func krakenXBTsSymbolAndClass() throws {
        let registry = try registry()
        #expect(try registry.asset(of: krakenXBT) == .btc)
        let declared = try registry.declaration(of: .btc).instances.first { $0.instance == krakenXBT }
        #expect(declared?.symbol.text == "XBT")
    }

    // "`exchange:hyperliquid:BTC` at 5, Hyperliquid's size decimals"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func hyperliquidBitcoinAtFive() throws {
        // invented: HyperliquidHolding.btc — the id is the design's; the constant's Swift name is not declared
        #expect(try registry().decimals(of: AssetInstance(HyperliquidHolding.btc)) == 5)
    }

    // "Their exchange holdings are library declarations beside them: `exchange:hyperliquid:USDC`, `exchange:kraken:USD`,
    // `exchange:coinbase:USD`, `exchange:binance:USDT`, `exchange:kraken:XBT`"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func theFivesHoldingsAreDeclared() throws {
        let registry = try registry()
        #expect(try registry.asset(of: AssetInstance(HyperliquidHolding.usdc)) == .usdc)
        // invented: CoinbaseHolding.usd — implied by "Coinbase's USD"; not written out
        #expect(try registry.asset(of: AssetInstance(CoinbaseHolding.usd)) == .usd)
        #expect(try registry.asset(of: krakenUSD) == .usd)
        #expect(try registry.asset(of: binanceUSDT) == .usdt)
        #expect(try registry.asset(of: krakenXBT) == .btc)
    }

    // "An account is an address, not an instance: `exchange:hyperliquid:four-hour-2x` is no asset's instance; `asset(of:)` throws `undeclaredInstance`."
    @Test func anAccountIsNoAssetsInstance() throws {
        let account = AssetInstance(HyperliquidHolding(address: "four-hour-2x"))
        let registry = try registry()
        #expect(throws: AssetRegistryError.undeclaredInstance(account)) { try registry.asset(of: account) }
    }

    // "One asset per instance: adding a second class that lists `exchange:binance:USDT` throws `instanceInTwoAssets`."
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func aSecondClassListingBinanceTetherThrows() throws {
        let registry = try registry()
        let impostor = try AssetDeclaration(
            asset: .stub(), tokenName: "Fred Coin", symbol: .stub(),
            instances: [AssetDeclaration.Instance(instance: .stub(), decimals: 4, symbol: .stub()),
                        AssetDeclaration.Instance(instance: binanceUSDT, decimals: 8, symbol: .stub())])
        #expect(throws: AssetRegistryError.instanceInTwoAssets(binanceUSDT)) { try registry.add([impostor]) }
    }

    // "Decimals never change: replacing `exchange:kraken:XBT` at 8 throws `decimalsChanged`."
    // Built outside the library declarations, since § 2.3 refuses any replace of a library declaration first.
    @Test func replacingKrakenXBTAtEightThrowsDecimalsChanged() throws {
        func declaration(_ decimals: Int) throws -> AssetDeclaration {
            try AssetDeclaration(asset: .stub(), tokenName: "Fred Coin", symbol: .stub(),
                                 instances: [AssetDeclaration.Instance(instance: .stub(), decimals: 4, symbol: .stub()),
                                             AssetDeclaration.Instance(instance: krakenXBT, decimals: decimals,
                                                                       symbol: AssetSymbol(validating: "XBT"))])
        }
        let registry = try AssetRegistry([declaration(10)])
        #expect(throws: AssetRegistryError.decimalsChanged(krakenXBT)) { try registry.replace([declaration(8)]) }
    }

    // "The dollar held on an exchange is an exchange holding ... `iso4217:USD` is the dollar itself, the class's home." (§ 1.4)
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func theDollarsHomeIsTheFiat() throws {
        let registry = try registry()
        #expect(try registry.instance(of: .usd, on: KrakenExchangeChain.default.id) == krakenUSD)
        #expect(try registry.declaration(of: .usd).instances.first?.instance == ISO4217.usd.instance)
    }

    // "The instance of `asset` on the chain or exchange `chainId`" — `try registry.instance(of: .btc, on: "exchange:kraken").id // \"exchange:kraken:XBT\"`
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func bitcoinOnKraken() throws {
        #expect(try registry().instance(of: .btc, on: KrakenExchangeChain.default.id).id == "exchange:kraken:XBT")
    }
}
