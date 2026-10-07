// D13 — An exchange is a chain.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.3: "An exchange is a `CryptoChain` conformer of a
// special kind." and "A holding is a declared constant of the exchange's plug-in ... Its address is the library's key
// for it, declared once on the constant ... The exchange's wire names live in one table per plug-in, and nowhere else
// ... `KrakenExchangeChain.default.contract(for: \"XXBT\")` answers `.xbt`, and a name the table lacks throws. The
// reverse, the one name the exchange accepts in an order, is the holding's `wireName`." And "Never `nil`".
// The four exchange chains are declared in CryptoOHLCV ("Where they live", second amendment of 2026-10-07).

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D13 Exchange chains")
struct D13_ExchangeChainsTests {
    // "`KrakenExchangeChain.default.id == \"exchange:kraken\"`"
    @Test func krakenId() {
        #expect(KrakenExchangeChain.default.id == "exchange:kraken")
    }

    // "`exchange:binance`, `exchange:coinbase`, `exchange:hyperliquid`, `exchange:kraken`."
    @Test func theOtherThreeIds() {
        #expect(BinanceExchangeChain.default.id == "exchange:binance")
        #expect(CoinbaseExchangeChain.default.id == "exchange:coinbase")
        #expect(HyperliquidExchangeChain.default.id == "exchange:hyperliquid")
    }

    // "`exchange:kraken` has the CAIP-2 shape and a namespace no chain uses, so it can never equal a chain's id"
    @Test func exchangeIdsAreInAnOwnedNamespace() {
        for id in [KrakenExchangeChain.default.id, BinanceExchangeChain.default.id,
                   CoinbaseExchangeChain.default.id, HyperliquidExchangeChain.default.id] {
            let namespace = String(id.prefix { $0 != ":" })
            #expect(AssetRegistry.ownedNamespaces.contains(namespace))
        }
    }

    // "so it can never equal a chain's id"
    @Test func noExchangeIdEqualsAChainsId() {
        let chains = [EthereumChain.default.id, BitcoinChain.default.id]
        for id in [KrakenExchangeChain.default.id, BinanceExchangeChain.default.id,
                   CoinbaseExchangeChain.default.id, HyperliquidExchangeChain.default.id] {
            #expect(!chains.contains(id))
        }
    }

    // "public let userReadableName: String = \"Kraken\""
    @Test func krakenReadableName() {
        #expect(KrakenExchangeChain.default.userReadableName == "Kraken")
    }

    // "The exchange's main contract is the holding its account's value is stated in: Hyperliquid's USDC, Kraken's USD,
    // Coinbase's USD, Binance's USDT."
    @Test func mainContracts() {
        #expect(KrakenExchangeChain.default.mainContract == KrakenHolding.usd)
        #expect(HyperliquidExchangeChain.default.mainContract == HyperliquidHolding.usdc)
        // invented: CoinbaseHolding.usd — § 1.3 says "one per holding the registry declares"; Coinbase's USD constant is not written out
        #expect(CoinbaseExchangeChain.default.mainContract == CoinbaseHolding.usd)
        #expect(BinanceExchangeChain.default.mainContract == BinanceHolding.usdt)
    }

    // "Its address is the library's key for it, declared once on the constant: \"XBT\", \"USD\", \"USDC\""
    @Test func holdingAddressesAreTheLibrarysKeys() {
        #expect(KrakenHolding.xbt.address == "XBT")
        #expect(KrakenHolding.usd.address == "USD")
        #expect(HyperliquidHolding.usdc.address == "USDC")
        #expect(BinanceHolding.usdt.address == "USDT")
    }

    // "The id `exchange:kraken:XBT` derives from the chain's id and this key by your 2023 rule"
    @Test func holdingIdDerivesFromTheChainAndTheKey() {
        #expect(KrakenHolding.xbt.id == KrakenExchangeChain.default.id + ":" + KrakenHolding.xbt.address)
        #expect(AssetInstance(KrakenHolding.xbt).id == "exchange:kraken:XBT")
    }

    // "Binance's tether: `exchange:binance:USDT`, the constant `BinanceHolding.usdt`."
    @Test func binanceTether() {
        #expect(AssetInstance(BinanceHolding.usdt).id == "exchange:binance:USDT")
    }

    // "Hyperliquid's coins: keys as Hyperliquid spells them, case included ... `exchange:hyperliquid:BTC`, `exchange:hyperliquid:kPEPE`"
    @Test func hyperliquidKeysKeepTheirCase() throws {
        // invented: HyperliquidHolding.btc and .kPEPE — the design writes the ids; the constants' Swift names are not declared
        #expect(AssetInstance(HyperliquidHolding.btc).id == "exchange:hyperliquid:BTC")
        #expect(AssetInstance(HyperliquidHolding.kPEPE).id == "exchange:hyperliquid:kPEPE")
        #expect(try HyperliquidExchangeChain.default.contract(for: "kPEPE") == HyperliquidHolding.kPEPE)
    }

    // "Kraken's \"XXBT\" and \"XBT\" both map to `.xbt`"
    @Test func krakenBitcoinWireNamesAreOneHolding() throws {
        #expect(try KrakenExchangeChain.default.contract(for: "XXBT") == .xbt)
        #expect(try KrakenExchangeChain.default.contract(for: "XBT") == .xbt)
    }

    // "its \"ZUSD\" and \"USD\" to `.usd`"
    @Test func krakenDollarWireNamesAreOneHolding() throws {
        #expect(try KrakenExchangeChain.default.contract(for: "ZUSD") == .usd)
        #expect(try KrakenExchangeChain.default.contract(for: "USD") == .usd)
    }

    // "a name the table lacks throws" — "A wire name the table lacks is a finding, never a holding minted from the string."
    @Test func anUnlistedWireNameThrows() {
        #expect(throws: (any Error).self) { try KrakenExchangeChain.default.contract(for: "FREDROCK") }
    }

    // "The reverse, the one name the exchange accepts in an order, is the holding's `wireName`." — it is in the table
    @Test func wireNameResolvesBackToItsHolding() throws {
        for holding in [KrakenHolding.xbt, .usd] {
            #expect(try KrakenExchangeChain.default.contract(for: holding.wireName) == holding)
        }
    }

    // "An exchange's symbol never holds one [colon] either; a test pins it for every declared holding." (§ 1.5)
    @Test func noDeclaredHoldingAddressHoldsAColon() {
        // invented: <Exchange>Holding.declared — the list of every declared constant; "one per holding the registry declares" names no member
        for address in KrakenHolding.declared.map(\.address) + BinanceHolding.declared.map(\.address)
            + CoinbaseHolding.declared.map(\.address) + HyperliquidHolding.declared.map(\.address) {
            #expect(!address.contains(":"))
        }
    }

    // "Your protocol's `scanner` becomes non-optional" — Kraken's is its adapter type
    @Test func krakenScannerIsItsAdapter() {
        let scanner: KrakenScanner = KrakenExchangeChain.default.scanner
        #expect(!scanner.userReadableName.isEmpty)
    }

    // "Binance's exchange chain, which has no account client, specifies `NilScanner<BinanceHolding>`."
    @Test func binanceScannerIsTheNilScanner() {
        let scanner: NilScanner<BinanceHolding> = BinanceExchangeChain.default.scanner
        #expect(scanner.userReadableName == "No scanner")
    }

    // "`BlockChains.register(_:)` is added, called when an exchange chain is made, and `contract(of:)` then answers for a holding too."
    @Test func blockChainsAnswersForAHoldingOnceTheChainIsMade() {
        _ = KrakenExchangeChain.default
        let contract = BlockChains.contract(of: AssetInstance(KrakenHolding.xbt))
        #expect((contract as? KrakenHolding) == KrakenHolding.xbt)
    }

    // "A sub-account or a portfolio is an address on it." — `exchange:hyperliquid:four-hour-2x`
    @Test func aSubAccountIsAnAddress() {
        let account = HyperliquidHolding(address: "four-hour-2x")
        #expect(account.id == "exchange:hyperliquid:four-hour-2x")
    }

    // "The id ... is never written by a client" — the holding's id is the bridge's id
    @Test func bridgeReadsTheHoldingsId() {
        for holding in [KrakenHolding.xbt, .usd] {
            #expect(AssetInstance(holding).id == holding.id)
        }
    }

    // "Codable" holdings — a holding round-trips
    @Test func holdingRoundTrips() throws {
        let data = try JSONEncoder().encode(KrakenHolding.xbt)
        #expect(try JSONDecoder().decode(KrakenHolding.self, from: data) == .xbt)
    }
}
