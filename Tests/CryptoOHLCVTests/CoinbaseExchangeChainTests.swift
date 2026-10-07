// CoinbaseExchangeChainTests.swift
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

// Design § 1.3 and § 6, "The exchange chains" and "The table, per plug-in": Coinbase as a chain, its holdings as its
// contracts, its wire names in one table, its declarations at its clients' init, the units check (AR45), against the
// recording of Coinbase's public product answer. Each test builds its own registry from the library's declarations.

@Suite("Coinbase's exchange chain")
struct CoinbaseExchangeChainTests {
    static func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // The recorded product's two currencies, each with the places of its increment.
    static var recordedCurrencies: [(name: String, places: Int)] {
        let product = Feed.json("Coinbase/product-btc-usd.json") as! [String: Any]
        func places(_ key: String) -> Int { (product[key] as! String).split(separator: ".").last.map { $0.count } ?? 0 }
        return [(product["base_currency_id"] as! String, places("base_increment")),
                (product["quote_currency_id"] as! String, places("quote_increment"))]
    }

    static func client(_ session: ReplaySession, registry: AssetRegistry) -> CoinbaseOHLCVClient {
        CoinbaseOHLCVClient(session: session, now: { Feed.coinbaseRecordedAt }, registry: registry)
    }

    static func session(product: String) -> ReplaySession {
        ReplaySession { request, _ in
            request.url!.lastPathComponent == "candles" ? .ok(Feed.body("Coinbase/candles-btc-usd-1d.json")) : .ok(Data(product.utf8))
        }
    }

    static var recordedProduct: String {
        String(decoding: Feed.body("Coinbase/product-btc-usd.json"), as: UTF8.self)
    }

    // MARK: The chain

    @Test func theChainsIdIsTheExchangeNamespacesConstant() {
        #expect(CoinbaseExchangeChain.default.id == EXCHANGE.Coinbase.chainId)
        #expect(CoinbaseExchangeChain.default.id == "exchange:coinbase")
    }

    @Test func theMainContractIsCoinbasesDollar() {
        #expect(CoinbaseExchangeChain.default.mainContract == CoinbaseHolding.usd)
        #expect(CoinbaseHolding.usd.isChainToken && !CoinbaseHolding.btc.isChainToken)
    }

    @Test func aHoldingsInstanceIsTheChainsIdAndItsKey() {
        #expect(AssetInstance(CoinbaseHolding.btc).id == "exchange:coinbase:BTC")
        #expect(AssetInstance(CoinbaseHolding.usd).id == "exchange:coinbase:USD")
    }

    @Test func theChainsTokensAreItsHoldings() throws {
        let symbols = Set(CoinbaseExchangeChain.default.chainTokenInfos.map(\.symbol))
        #expect(symbols == ["BTC", "ETH", "USD"])
        let btc = try #require(CoinbaseExchangeChain.default.tokenInfo(for: CoinbaseHolding.btc.address))
        #expect(btc.symbol == "BTC" && btc.tokenName == "Bitcoin")
    }

    // MARK: The table

    @Test func aCurrencyIdIsItsHolding() throws {
        let chain = CoinbaseExchangeChain.default
        #expect(try chain.contract(for: "BTC") == CoinbaseHolding.btc)
        #expect(try chain.contract(for: "ETH") == CoinbaseHolding.eth)
        #expect(try chain.contract(for: "USD") == CoinbaseHolding.usd)
    }

    @Test(arguments: ["USDC", "btc", "BTC-USD", ""])
    func aNameTheTableLacksThrows(name: String) {
        #expect(throws: AssetError.malformedIdentity(name)) { try CoinbaseExchangeChain.default.contract(for: name) }
    }

    @Test func everyCurrencyOfTheRecordedProductResolvesThroughTheTable() throws {
        for currency in Self.recordedCurrencies {
            #expect(throws: Never.self) { try CoinbaseExchangeChain.default.contract(for: currency.name) }
        }
    }

    @Test func btcsAndUSDsWireNamesAreTheRecordedProductsCurrencies() {
        // The recorded product's id, "BTC-USD", is its two currencies' ids, which the request names it by.
        #expect(CoinbaseHolding.btc.wireName + "-" + CoinbaseHolding.usd.wireName == "BTC-USD")
        #expect(Self.recordedCurrencies.map(\.name) == [CoinbaseHolding.btc.wireName, CoinbaseHolding.usd.wireName])
    }

    // MARK: The declarations

    @Test func theRecordedProductYieldsBTCAtEightAndUSDAtTwoDeclared() throws {
        let registry = try Self.registry()
        try CoinbaseExchangeChain.declare(in: registry)
        var declared: [String: Int] = [:]
        for currency in Self.recordedCurrencies {
            let instance = try #require(try CoinbaseExchangeChain.declaredInstance(wireName: currency.name, decimals: currency.places, in: registry))
            declared[instance.id] = try registry.decimals(of: instance)
        }
        #expect(declared == ["exchange:coinbase:BTC": 8, "exchange:coinbase:USD": 2])
    }

    @Test func btcsClassIsBitcoinAndUSDsIsTheDollar() throws {
        let registry = try Self.registry()
        try CoinbaseExchangeChain.declare(in: registry)
        let btc = AssetInstance(CoinbaseHolding.btc)
        #expect(try registry.asset(of: btc) == .btc)
        #expect(try registry.instance(of: .btc, on: EXCHANGE.Coinbase.chainId) == btc)
        #expect(try registry.asset(of: AssetInstance(CoinbaseHolding.usd)) == .usd)
        #expect(try registry.asset(of: AssetInstance(CoinbaseHolding.eth)) == .eth)
    }

    @Test func declaringTwiceIsDeclaringOnce() throws {
        let registry = try Self.registry()
        try CoinbaseExchangeChain.declare(in: registry)
        try CoinbaseExchangeChain.declare(in: registry)
        #expect(try registry.decimals(of: AssetInstance(CoinbaseHolding.btc)) == 8)
        #expect(try registry.declaration(of: .btc).instances.count == 2)
    }

    @Test func aPortfolioOnCoinbaseIsNoInstance() throws {
        let registry = try Self.registry()
        try CoinbaseExchangeChain.declare(in: registry)
        let portfolio = AssetInstance(CoinbaseHolding(address: "8bfc20d7-f7c6-4422-bf07-8243ca4169fe"))
        #expect(throws: AssetRegistryError.undeclaredInstance(portfolio)) { try registry.asset(of: portfolio) }
    }

    @Test func theDeclaredChainIsKnownToBlockChains() throws {
        try CoinbaseExchangeChain.declare(in: Self.registry())
        #expect(BlockChains.contract(of: AssetInstance(CoinbaseHolding.btc)) as? CoinbaseHolding == CoinbaseHolding.btc)
    }

    // MARK: The units check (AR45) and the candle client

    @Test func aRecordedCandleLandsOnBTCAndUSD() async throws {
        let bars = try await Self.client(Self.session(product: Self.recordedProduct), registry: Self.registry())
            .ohlcv(market: CoinbaseOHLCVClientContractTests.btcusd, interval: Feed.day,
                   from: CoinbaseOHLCVClientContractTests.from, through: CoinbaseOHLCVClientContractTests.through)
        let first = try #require(bars.first)
        #expect(first.open.base == AssetInstance(CoinbaseHolding.btc))
        #expect(first.open.quote == AssetInstance(CoinbaseHolding.usd))
        #expect(first.volume.instance == AssetInstance(CoinbaseHolding.btc))
    }

    @Test func aRecordedProductWithAFinerIncrementRaisesTheUnitsFinding() async throws {
        let product = Self.recordedProduct
            .replacingOccurrences(of: #""base_increment":"0.00000001""#, with: #""base_increment":"0.0000000001""#)
        #expect(product.contains(#""base_increment":"0.0000000001""#))
        await #expect(throws: AssetRegistryError.decimalsChanged(AssetInstance(CoinbaseHolding.btc))) {
            try await Self.client(Self.session(product: product), registry: Self.registry())
                .ohlcv(market: CoinbaseOHLCVClientContractTests.btcusd, interval: Feed.day,
                       from: CoinbaseOHLCVClientContractTests.from, through: CoinbaseOHLCVClientContractTests.through)
        }
    }

    @Test func aCoarserIncrementIsNoFinding() throws {
        // BTC-PERP-INTX steps BTC by "0.0001": a step, not the holding's count.
        let registry = try Self.registry()
        try CoinbaseExchangeChain.declare(in: registry)
        #expect(try CoinbaseExchangeChain.declaredInstance(wireName: "BTC", decimals: 4, in: registry) == AssetInstance(CoinbaseHolding.btc))
    }

    @Test func aCurrencyTheTableLacksIsAFindingNeverAHolding() async throws {
        let product = Self.recordedProduct.replacingOccurrences(of: #""quote_currency_id":"USD""#, with: #""quote_currency_id":"USDC""#)
        #expect(product.contains(#""quote_currency_id":"USDC""#))
        await #expect(throws: AssetError.malformedIdentity("USDC")) {
            try await Self.client(Self.session(product: product), registry: Self.registry())
                .ohlcv(market: CoinbaseOHLCVClientContractTests.btcusd, interval: Feed.day,
                       from: CoinbaseOHLCVClientContractTests.from, through: CoinbaseOHLCVClientContractTests.through)
        }
    }

    @Test func theCandleClientDeclaresCoinbaseInItsRegistry() throws {
        let registry = try Self.registry()
        _ = Self.client(Self.session(product: Self.recordedProduct), registry: registry)
        #expect(try registry.decimals(of: AssetInstance(CoinbaseHolding.usd)) == 2)
    }

    // MARK: The scanner, unconfigured

    @Test func anUnconfiguredScannerThrowsAndIsNotAvailable() async throws {
        let scanner = CoinbaseScanner()
        #expect(!scanner.isAvailable)
        #expect(scanner.userReadableName == "Coinbase")
        do {
            _ = try await scanner.getBalance(forAccount: .stub())
            Issue.record("An unconfigured scanner answered")
        } catch let error as ExchangeClientError {
            guard case .unauthorized(let text) = error else {
                Issue.record("Not unauthorized: \(error)")
                return
            }
            #expect(text.contains("Coinbase"))
        }
        await #expect(throws: ExchangeClientError.self) { try await scanner.getTransactions(forAccount: .stub()) }
    }
}
