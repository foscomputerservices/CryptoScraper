// BinanceExchangeChainTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// Design § 1.3, § 2.1, § 2.6 and § 6, "The exchange chains", "The table, per plug-in" and "The exchange scanners":
// Binance as a chain, its holdings as its contracts, its wire names in one table, its declarations at its candle
// client's init, the units check (AR45) against the recorded exchange information, its scanner the NilScanner, and its
// tether at 8 one class with Ethereum's at 6. Each test builds its own registry from the library's declarations.
// CryptoScraper's 2023 amount and CryptoAsset's meet in this file, so CryptoAsset's is written `CryptoAsset.Amount`.

@Suite("Binance's exchange chain")
struct BinanceExchangeChainTests {
    static func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    static let btcusdt = try! BinanceMarketName(validating: "BTCUSDT")

    // The recorded exchange information's markets: each symbol's base and quote asset with the precision Binance
    // states for each.
    static var recordedSymbols: [(symbol: String, base: String, basePrecision: Int, quote: String, quotePrecision: Int)] {
        let symbols = (try! JSONSerialization.jsonObject(with: Recorded.exchangeInfo) as! [String: Any])["symbols"] as! [[String: Any]]
        return symbols.map {
            ($0["symbol"] as! String, $0["baseAsset"] as! String, ($0["baseAssetPrecision"] as! NSNumber).intValue,
             $0["quoteAsset"] as! String, ($0["quoteAssetPrecision"] as! NSNumber).intValue)
        }
    }

    // The recorded exchange information with one text replaced, checked to have been replaced.
    static func exchangeInfo(replacing old: String, with new: String) -> Data {
        let text = String(decoding: Recorded.exchangeInfo, as: UTF8.self)
        precondition(text.contains(old), "the recording no longer holds \(old)")
        return Data(text.replacingOccurrences(of: old, with: new).utf8)
    }

    static func client(_ session: ReplaySession, registry: AssetRegistry) -> BinanceOHLCVClient {
        BinanceOHLCVClient(session: session, now: { Recorded.recordedAt }, registry: registry)
    }

    // MARK: The chain

    @Test func theChainsIdIsTheExchangeNamespacesConstant() {
        #expect(BinanceExchangeChain.default.id == EXCHANGE.Binance.chainId)
        #expect(BinanceExchangeChain.default.id == "exchange:binance")
        #expect(AssetRegistry.ownedNamespaces.contains(EXCHANGE.namespace))
    }

    @Test func theMainContractIsBinancesTether() {
        #expect(BinanceExchangeChain.default.mainContract == BinanceHolding.usdt)
        #expect(BinanceHolding.usdt.isChainToken && !BinanceHolding.btc.isChainToken)
    }

    @Test func aHoldingsInstanceIsTheChainsIdAndItsKey() {
        #expect(AssetInstance(BinanceHolding.btc).id == "exchange:binance:BTC")
        #expect(AssetInstance(BinanceHolding.usdt).id == "exchange:binance:USDT")
    }

    @Test func theChainsTokensAreItsHoldings() throws {
        let symbols = Set(BinanceExchangeChain.default.chainTokenInfos.map(\.symbol))
        // The two the recording states, among the top-1000 run's (2026-10-07)
        #expect(symbols.isSuperset(of: ["BTC", "USDT"]))
        let usdt = try #require(BinanceExchangeChain.default.tokenInfo(for: BinanceHolding.usdt.address))
        #expect(usdt.symbol == "USDT" && usdt.tokenName == "Tether")
    }

    // MARK: The table

    @Test func eachRecordedAssetNameIsItsHolding() throws {
        let chain = BinanceExchangeChain.default
        #expect(try chain.contract(for: "BTC") == BinanceHolding.btc)
        #expect(try chain.contract(for: "USDT") == BinanceHolding.usdt)
    }

    // "ETH" was the unlisted name until the top-1000 run of 2026-10-07 listed it; FRED is the reserved fake
    @Test(arguments: ["FRED", "BTCUSDT", "usdt", ""])
    func aNameTheTableLacksThrows(name: String) {
        #expect(throws: AssetError.self) { try BinanceExchangeChain.default.contract(for: name) }
    }

    @Test func everyAssetInTheRecordedExchangeInformationResolvesThroughTheTable() throws {
        let names = Self.recordedSymbols.flatMap { [$0.base, $0.quote] }
        #expect(names == ["BTC", "USDT"])
        for name in names {
            #expect(throws: Never.self) { try BinanceExchangeChain.default.contract(for: name) }
        }
    }

    @Test func eachHoldingsWireNameIsTheNameTheRecordedExchangeInformationGives() throws {
        let recorded = try #require(Self.recordedSymbols.first)
        #expect(BinanceHolding.btc.wireName == recorded.base)
        #expect(BinanceHolding.usdt.wireName == recorded.quote)
        #expect(BinanceHolding.btc.wireName + BinanceHolding.usdt.wireName == recorded.symbol)
    }

    // MARK: The declarations

    @Test func theRecordedExchangeInformationYieldsBTCAndUSDTAtEightDeclared() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        var declared: [String: Int] = [:]
        for entry in Self.recordedSymbols {
            for (name, precision) in [(entry.base, entry.basePrecision), (entry.quote, entry.quotePrecision)] {
                let instance = try #require(try BinanceExchangeChain.declaredInstance(wireName: name, decimals: precision, in: registry))
                declared[instance.id] = try registry.decimals(of: instance)
            }
        }
        #expect(declared == ["exchange:binance:BTC": 8, "exchange:binance:USDT": 8])
    }

    @Test func btcsClassIsBitcoinAndUSDTsIsTether() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        let usdt = AssetInstance(BinanceHolding.usdt)
        #expect(try registry.asset(of: AssetInstance(BinanceHolding.btc)) == .btc)
        #expect(try registry.asset(of: usdt) == .usdt)
        #expect(try registry.instance(of: .usdt, on: EXCHANGE.Binance.chainId) == usdt)
        let declared = try #require(try registry.declaration(of: .usdt).instances.first { $0.instance == usdt })
        #expect(declared.symbol.text == "USDT")
    }

    @Test func declaringTwiceIsDeclaringOnce() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        try BinanceExchangeChain.declare(in: registry)
        #expect(try registry.decimals(of: AssetInstance(BinanceHolding.usdt)) == 8)
        #expect(try registry.declaration(of: .usdt).instances.count == Assets.tether.instances.count + 1)
    }

    @Test func anAccountOnBinanceIsNoInstance() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(BinanceHolding(address: "four-hour-2x")))) {
            try registry.asset(of: AssetInstance(BinanceHolding(address: "four-hour-2x")))
        }
    }

    @Test func theDeclaredChainIsKnownToBlockChains() throws {
        try BinanceExchangeChain.declare(in: Self.registry())
        #expect(BlockChains.contract(of: AssetInstance(BinanceHolding.usdt)) as? BinanceHolding == BinanceHolding.usdt)
    }

    // MARK: One class across the exchange and the chain (design § 2.1, § 2.6)

    @Test func binancesTetherAtEightAndEthereumsAtSixAreOneClass() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        let binance = AssetInstance(BinanceHolding.usdt)
        let ethereum = try registry.instance(of: .usdt, on: EIP155.Ethereum.chainId)
        #expect(try registry.asset(of: binance) == registry.asset(of: ethereum))
        #expect(try registry.isEquivalent(binance, ethereum))
        #expect(try registry.decimals(of: binance) == 8)
        #expect(try registry.decimals(of: ethereum) == 6)
    }

    @Test func binancesTetherDustRefusesConversionDownToEthereums() throws {
        let registry = try Self.registry()
        try BinanceExchangeChain.declare(in: registry)
        let binance = AssetInstance(BinanceHolding.usdt)
        let ethereum = try registry.instance(of: .usdt, on: EIP155.Ethereum.chainId)
        let dust = CryptoAsset.Amount(baseUnits: 12_345_678, of: binance)          // 0.12345678
        #expect(throws: AmountError.notRepresentable(dust, in: ethereum)) {
            try dust.converted(to: ethereum, in: registry)
        }
        let whole = CryptoAsset.Amount(baseUnits: 12_345_600, of: binance)         // 0.123456
        #expect(try whole.converted(to: ethereum, in: registry) == CryptoAsset.Amount(baseUnits: 123_456, of: ethereum))
    }

    // MARK: The units check (AR45) and the candle client

    @Test func aRecordedMarketLandsOnBTCAndUSDT() async throws {
        let session = ReplaySession(route: binanceRoute)
        let client = Self.client(session, registry: try Self.registry())
        let market = try await client.market(Self.btcusdt)
        #expect(market.base == AssetInstance(BinanceHolding.btc))
        #expect(market.quote == AssetInstance(BinanceHolding.usdt))
        #expect(market.baseSymbol.text == "BTC" && market.baseDecimals == 8)
        #expect(market.quoteSymbol.text == "USDT" && market.quoteDecimals == 8)
        let first = try #require(try await client.ohlcv(market: Self.btcusdt, interval: Binance.day, from: Recorded.rangeStart,
                                                         through: Recorded.rangeEnd).first)
        #expect(first.open.base == AssetInstance(BinanceHolding.btc))
        #expect(first.open.quote == AssetInstance(BinanceHolding.usdt))
        #expect(first.volume.instance == AssetInstance(BinanceHolding.btc))
    }

    @Test func aRecordedExchangeInformationWithBTCAtSixRaisesTheUnitsFinding() async throws {
        let changed = Self.exchangeInfo(replacing: #""baseAsset":"BTC","baseAssetPrecision":8"#,
                                        with: #""baseAsset":"BTC","baseAssetPrecision":6"#)
        let session = ReplaySession { request, _ in
            request.url!.path.hasSuffix("exchangeInfo") ? .ok(changed) : binanceRoute(request, 0)
        }
        await #expect(throws: AssetRegistryError.decimalsChanged(AssetInstance(BinanceHolding.btc))) {
            try await Self.client(session, registry: Self.registry())
                .ohlcv(market: Self.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    @Test func anUndeclaredBaseGivesAMarketWithANilHoldingAndBinancesNamesAsFacts() async throws {
        // PEPE was the undeclared base until the top-1000 run of 2026-10-07 declared it (at Binance's 2); FRED is
        // the reserved fake no table lists
        let fred = Self.exchangeInfo(replacing: #""symbol":"BTCUSDT","status":"TRADING","baseAsset":"BTC""#,
                                     with: #""symbol":"FREDUSDT","status":"TRADING","baseAsset":"FRED""#)
        let session = ReplaySession { _, _ in .ok(fred) }
        let client = Self.client(session, registry: try Self.registry())
        let name = try BinanceMarketName(validating: "FREDUSDT")
        let market = try await client.market(name)
        #expect(market.base == nil)
        #expect(market.baseSymbol.text == "FRED" && market.baseDecimals == 8)
        #expect(market.quote == AssetInstance(BinanceHolding.usdt))
        await #expect(throws: BinanceOHLCVError.unknownMarket(name)) {
            try await client.ohlcv(market: name, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    @Test func theCandleClientDeclaresBinanceInItsRegistry() throws {
        let registry = try Self.registry()
        _ = BinanceOHLCVClient(session: ReplaySession(route: binanceRoute), registry: registry)
        #expect(try registry.decimals(of: AssetInstance(BinanceHolding.usdt)) == 8)
        #expect(try registry.decimals(of: AssetInstance(BinanceHolding.btc)) == 8)
    }

    // Step 8c: a row whose class is a generated asset resolves as declared. Binance's USDT is generated in
    // Assets.tether's class; at the client's start it is declared in the shared registry beside every instance the
    // generated declaration lists.
    @Test func binancesUSDTLandsInTheGeneratedTethersClassDeclaredInTheSharedRegistry() throws {
        let usdt = AssetInstance(BinanceHolding.usdt)
        try BinanceExchangeChain.declare(in: .shared)

        #expect(try AssetRegistry.shared.asset(of: usdt) == Assets.tether.asset)
        #expect(try AssetRegistry.shared.decimals(of: usdt) == 8)
        let tether = try AssetRegistry.shared.declaration(of: Assets.tether.asset)
        #expect(tether.tokenName == Assets.tether.tokenName && tether.aggregatorId == Assets.tether.aggregatorId)
        #expect(Array(tether.instances.prefix(Assets.tether.instances.count)) == Assets.tether.instances)
        #expect(tether.instances.map(\.instance).contains(usdt))
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerAnsweringZeroAndNothing() async throws {
        let scanner: NilScanner<BinanceHolding> = BinanceExchangeChain.default.scanner
        #expect(scanner.userReadableName == "No scanner")
        #expect(try await scanner.getBalance(forAccount: .stub()).quantity == 0)
        #expect(try await scanner.getBalance(forToken: .btc, forAccount: .stub()).quantity == 0)
        #expect(try await scanner.getTransactions(forAccount: .stub()).isEmpty)
        #expect(try scanner.loadTransactions(from: Data("[]".utf8)).isEmpty)
    }
}
