// KrakenExchangeChainTests.swift
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

// Design § 1.3 and § 6, "The exchange chains" and "The table, per plug-in": Kraken as a chain, its holdings as its
// contracts, its wire names in one table, its declarations at its clients' init, the units check (AR45), against
// the recordings of Kraken's public answers. Each test builds its own registry from the library's declarations.

@Suite("Kraken's exchange chain")
struct KrakenExchangeChainTests {
    static func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // The recorded Assets answer's entries: Kraken's key, its alternative name, its decimals.
    static var recordedAssets: [(key: String, altname: String, decimals: Int)] {
        let result = (Feed.json("Kraken/assets-xbt-zusd.json") as! [String: Any])["result"] as! [String: [String: Any]]
        return result.map { ($0.key, $0.value["altname"] as! String, ($0.value["decimals"] as! NSNumber).intValue) }
            .sorted { $0.key < $1.key }
    }

    // MARK: The chain

    @Test func theChainsIdIsTheExchangeNamespacesConstant() {
        #expect(KrakenExchangeChain.default.id == EXCHANGE.Kraken.chainId)
        #expect(KrakenExchangeChain.default.id == "exchange:kraken")
        #expect(AssetRegistry.ownedNamespaces.contains(EXCHANGE.namespace))
    }

    @Test func theMainContractIsKrakensDollar() {
        #expect(KrakenExchangeChain.default.mainContract == KrakenHolding.usd)
        #expect(KrakenHolding.usd.isChainToken && !KrakenHolding.xbt.isChainToken)
    }

    @Test func aHoldingsInstanceIsTheChainsIdAndItsKey() {
        #expect(AssetInstance(KrakenHolding.xbt).id == "exchange:kraken:XBT")
        #expect(AssetInstance(KrakenHolding.usd).id == "exchange:kraken:USD")
    }

    @Test func theChainsTokensAreItsHoldings() throws {
        let symbols = Set(KrakenExchangeChain.default.chainTokenInfos.map(\.symbol))
        // The four the recording states, among the top-1000 run's (2026-10-07)
        #expect(symbols.isSuperset(of: ["XBT", "USD", "ETH", "SOL"]))
        let xbt = try #require(KrakenExchangeChain.default.tokenInfo(for: KrakenHolding.xbt.address))
        #expect(xbt.symbol == "XBT" && xbt.tokenName == "Bitcoin")
    }

    // MARK: The table

    @Test func krakensTwoNamesForAHoldingAreOneHolding() throws {
        let chain = KrakenExchangeChain.default
        #expect(try chain.contract(for: "XXBT") == chain.contract(for: "XBT"))
        #expect(try chain.contract(for: "XXBT") == KrakenHolding.xbt)
        #expect(try chain.contract(for: "ZUSD") == KrakenHolding.usd)
        #expect(try chain.contract(for: "USD") == KrakenHolding.usd)
    }

    @Test(arguments: ["ZGBP", "XXBTZUSD", "xbt", ""])
    func aNameTheTableLacksThrows(name: String) {
        #expect(throws: AssetError.self) { try KrakenExchangeChain.default.contract(for: name) }
    }

    @Test func everyWireNameInTheRecordedListingResolvesThroughTheTable() throws {
        let pairs = (Feed.json("Kraken/asset-pairs-xbtusd.json") as! [String: Any])["result"] as! [String: [String: Any]]
        let names = pairs.values.flatMap { [$0["base"] as! String, $0["quote"] as! String] }
            + Self.recordedAssets.flatMap { [$0.key, $0.altname] }
        for name in names {
            #expect(throws: Never.self) { try KrakenExchangeChain.default.contract(for: name) }
        }
    }

    @Test func xbtsWireNameIsTheOneKrakenAcceptsInAnOrder() {
        // The recorded market's alternative name, "XBTUSD", is what an order sends as its pair.
        #expect(KrakenHolding.xbt.wireName + KrakenHolding.usd.wireName == "XBTUSD")
    }

    // MARK: The declarations

    @Test func theRecordedAssetsAnswerYieldsXBTAtTenAndUSDAtFourDeclared() throws {
        let registry = try Self.registry()
        try KrakenExchangeChain.declare(in: registry)
        var declared: [String: Int] = [:]
        for entry in Self.recordedAssets {
            let instance = try #require(try KrakenExchangeChain.declaredInstance(wireName: entry.key, decimals: entry.decimals, in: registry))
            declared[instance.id] = try registry.decimals(of: instance)
        }
        #expect(declared == ["exchange:kraken:XBT": 10, "exchange:kraken:USD": 4])
    }

    @Test func xbtsSymbolIsXBTAndItsClassIsBitcoin() throws {
        let registry = try Self.registry()
        try KrakenExchangeChain.declare(in: registry)
        let xbt = AssetInstance(KrakenHolding.xbt)
        #expect(try registry.asset(of: xbt) == .btc)
        #expect(try registry.instance(of: .btc, on: EXCHANGE.Kraken.chainId) == xbt)
        let declared = try #require(try registry.declaration(of: .btc).instances.first { $0.instance == xbt })
        #expect(declared.symbol.text == "XBT")
        #expect(try registry.asset(of: AssetInstance(KrakenHolding.usd)) == .usd)
    }

    @Test func declaringTwiceIsDeclaringOnce() throws {
        let registry = try Self.registry()
        try KrakenExchangeChain.declare(in: registry)
        try KrakenExchangeChain.declare(in: registry)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.xbt)) == 10)
        #expect(try registry.declaration(of: .btc).instances.count == 2)
    }

    // Every row of Kraken's recorded table now has its class (Solana admitted), so the example of a holding with no
    // class is one in the test's own registry, the library's declarations alone, which hold no Kraken holding
    @Test func aHoldingWithNoDeclaredClassIsNoInstance() throws {
        let registry = try Self.registry()
        #expect(try KrakenExchangeChain.declaredInstance(wireName: "SOL", decimals: 10, in: registry) == nil)
    }

    @Test func solIsDeclaredInSolanasClass() throws {
        let registry = try Self.registry()
        try KrakenExchangeChain.declare(in: registry)
        let sol = try #require(try KrakenExchangeChain.declaredInstance(wireName: "SOL", decimals: 10, in: registry))
        #expect(sol == AssetInstance(KrakenHolding.sol))
        #expect(try registry.asset(of: sol) == registry.asset(of: SOLANA.Solana.sol.instance))
    }

    @Test func anAccountOnKrakenIsNoInstance() throws {
        let registry = try Self.registry()
        try KrakenExchangeChain.declare(in: registry)
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(KrakenHolding(address: "four-hour-2x")))) {
            try registry.asset(of: AssetInstance(KrakenHolding(address: "four-hour-2x")))
        }
    }

    @Test func theDeclaredChainIsKnownToBlockChains() throws {
        try KrakenExchangeChain.declare(in: Self.registry())
        #expect(BlockChains.contract(of: AssetInstance(KrakenHolding.xbt)) as? KrakenHolding == KrakenHolding.xbt)
    }

    // MARK: The units check (AR45) and the candle client

    @Test func aRecordedMarketLandsOnXBTAndUSD() async throws {
        let session = ReplaySession(route: KrakenOHLCVClientContractTests.route)
        let bars = try await KrakenOHLCVClientContractTests.client(session)
            .ohlcv(market: KrakenOHLCVClientContractTests.xbtusd, interval: Feed.day,
                   from: KrakenOHLCVClientContractTests.from, through: KrakenOHLCVClientContractTests.through)
        let first = try #require(bars.first)
        #expect(first.open.base == AssetInstance(KrakenHolding.xbt))
        #expect(first.open.quote == AssetInstance(KrakenHolding.usd))
        #expect(first.volume.instance == AssetInstance(KrakenHolding.xbt))
    }

    @Test func aRecordedAnswerWithXBTAtEightRaisesTheUnitsFinding() async throws {
        let assets = String(decoding: Feed.body("Kraken/assets-xbt-zusd.json"), as: UTF8.self)
            .replacingOccurrences(of: #""altname":"XBT","decimals":10"#, with: #""altname":"XBT","decimals":8"#)
        #expect(assets.contains(#""decimals":8"#))
        let session = ReplaySession { request, _ in
            switch request.url!.lastPathComponent {
            case "AssetPairs": .ok(Feed.body("Kraken/asset-pairs-xbtusd.json"))
            case "Assets": .ok(Data(assets.utf8))
            default: .ok(Feed.body("Kraken/ohlc-xbtusd-1d.json"))
            }
        }
        await #expect(throws: AssetRegistryError.decimalsChanged(AssetInstance(KrakenHolding.xbt))) {
            try await KrakenOHLCVClient(session: session, now: { Feed.krakenRecordedAt }, registry: Self.registry())
                .ohlcv(market: KrakenOHLCVClientContractTests.xbtusd, interval: Feed.day,
                       from: KrakenOHLCVClientContractTests.from, through: KrakenOHLCVClientContractTests.through)
        }
    }

    @Test func theCandleClientDeclaresKrakenInItsRegistry() throws {
        let registry = try Self.registry()
        _ = KrakenOHLCVClient(session: ReplaySession(route: KrakenOHLCVClientContractTests.route), registry: registry)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.usd)) == 4)
    }

    // MARK: The scanner, unconfigured

    @Test func anUnconfiguredScannerThrowsAndIsNotAvailable() async throws {
        let scanner = KrakenScanner()
        #expect(!scanner.isAvailable)
        #expect(scanner.userReadableName == "Kraken")
        do {
            _ = try await scanner.getBalance(forAccount: .stub())
            Issue.record("An unconfigured scanner answered")
        } catch let error as ExchangeClientError {
            guard case .unauthorized(let text) = error else {
                Issue.record("Not unauthorized: \(error)")
                return
            }
            #expect(text.contains("Kraken"))
        }
        await #expect(throws: ExchangeClientError.self) { try await scanner.getTransactions(forAccount: .stub()) }
    }
}
