// HyperliquidExchangeChainTests.swift
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

// Design § 1.3 and § 6, "The exchange chains" and "The table, per plug-in": Hyperliquid as a chain, its holdings as
// its contracts, its wire names in one table, its declarations at its clients' init, the units check (AR45), against
// the recordings of Hyperliquid's public answers. Each test builds its own registry from the library's declarations.

@Suite("Hyperliquid's exchange chain")
struct HyperliquidExchangeChainTests {
    static func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // The recorded `meta` answer's coins: Hyperliquid's name and its size decimals.
    static var recordedCoins: [(name: String, szDecimals: Int)] {
        let universe = (Feed.json("Hyperliquid/meta.json") as! [String: Any])["universe"] as! [[String: Any]]
        return universe.map { ($0["name"] as! String, ($0["szDecimals"] as! NSNumber).intValue) }
    }

    // MARK: The chain

    @Test func theChainsIdIsTheExchangeNamespacesConstant() {
        #expect(HyperliquidExchangeChain.default.id == EXCHANGE.Hyperliquid.chainId)
        #expect(HyperliquidExchangeChain.default.id == "exchange:hyperliquid")
    }

    @Test func theMainContractIsHyperliquidsUSDC() {
        #expect(HyperliquidExchangeChain.default.mainContract == HyperliquidHolding.usdc)
        #expect(HyperliquidHolding.usdc.isChainToken && !HyperliquidHolding.btc.isChainToken)
    }

    @Test func aHoldingsInstanceIsTheChainsIdAndItsKeyCaseIncluded() {
        #expect(AssetInstance(HyperliquidHolding.btc).id == "exchange:hyperliquid:BTC")
        #expect(AssetInstance(HyperliquidHolding.usdc).id == "exchange:hyperliquid:USDC")
        #expect(AssetInstance(HyperliquidHolding.kPEPE).id == "exchange:hyperliquid:kPEPE")
    }

    @Test func theChainsTokensAreItsHoldings() throws {
        let symbols = Set(HyperliquidExchangeChain.default.chainTokenInfos.map(\.symbol))
        // Carried in step 4c of the identity PR: BNB, POL and TRX joined the table, at the size decimals `meta` states.
        // DOGE, SAND, NEO, RUNE and ALGO joined on 2026-10-09, the suite's picks the testnet refused undeclared.
        #expect(symbols == ["BTC", "ETH", "USDC", "SOL", "kPEPE", "BNB", "POL", "TRX", "DOGE", "SAND", "NEO", "RUNE", "ALGO"])
        let btc = try #require(HyperliquidExchangeChain.default.tokenInfo(for: HyperliquidHolding.btc.address))
        #expect(btc.symbol == "BTC" && btc.tokenName == "Bitcoin")
    }

    // MARK: The table

    @Test func aCoinsOneNameIsItsHolding() throws {
        let chain = HyperliquidExchangeChain.default
        #expect(try chain.contract(for: "BTC") == HyperliquidHolding.btc)
        #expect(try chain.contract(for: "USDC") == HyperliquidHolding.usdc)
        #expect(try chain.contract(for: "kPEPE") == HyperliquidHolding.kPEPE)
    }

    // COTI and NMR: the suite's picks Hyperliquid lists on neither network (read 2026-10-09), findings, never rows.
    @Test(arguments: ["KPEPE", "btc", "neo", "COTI", "NMR", "@107", ""])
    func aNameTheTableLacksThrows(name: String) {
        #expect(throws: AssetError.malformedIdentity(name)) { try HyperliquidExchangeChain.default.contract(for: name) }
    }

    @Test func everyCoinInTheRecordedListingResolvesOrIsAFinding() throws {
        var resolved: [String] = []
        for coin in Self.recordedCoins {
            if let holding = try? HyperliquidExchangeChain.default.contract(for: coin.name) {
                resolved.append(holding.address)
            } else {
                #expect(throws: AssetError.malformedIdentity(coin.name)) { try HyperliquidExchangeChain.default.contract(for: coin.name) }
            }
        }
        // Carried in step 4c of the identity PR: BNB, POL and TRX joined the table, at the size decimals `meta` states.
        // DOGE, SAND, NEO, RUNE and ALGO joined on 2026-10-09.
        #expect(Set(resolved) == ["BTC", "ETH", "SOL", "kPEPE", "BNB", "POL", "TRX", "DOGE", "SAND", "NEO", "RUNE", "ALGO"])
    }

    @Test func btcsWireNameIsTheCoinTheRecordedRequestSends() async throws {
        let session = ReplaySession(route: HyperliquidOHLCVClientContractTests.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let market = try HyperliquidMarketName(validating: HyperliquidHolding.btc.wireName)
        _ = try await HyperliquidOHLCVClientContractTests.client(session)
            .ohlcv(market: market, interval: Feed.day, from: HyperliquidOHLCVClientContractTests.from, through: HyperliquidOHLCVClientContractTests.through)
        let request = try #require(session.requests.last?.jsonBody["req"] as? [String: Any])
        #expect(request["coin"] as? String == HyperliquidHolding.btc.wireName)
        #expect(HyperliquidHolding.btc.wireName == "BTC")
    }

    // MARK: The declarations

    @Test func theRecordedMetaYieldsBTCAtFiveAndETHAtFourDeclared() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        var declared: [String: Int] = [:]
        for coin in Self.recordedCoins {
            if let instance = try HyperliquidExchangeChain.declaredInstance(wireName: coin.name, decimals: coin.szDecimals, in: registry) {
                declared[instance.id] = try registry.decimals(of: instance)
            }
        }
        // Carried in step 4c of the identity PR: BNB, POL and TRX joined the table, at the size decimals `meta` states.
        // SOL joined at 2 when Solana's class was named on its row.
        // DOGE, SAND, NEO, RUNE and ALGO joined on 2026-10-09 at the size decimals `meta` states.
        #expect(declared == ["exchange:hyperliquid:BTC": 5, "exchange:hyperliquid:ETH": 4, "exchange:hyperliquid:BNB": 3,
                             "exchange:hyperliquid:POL": 0, "exchange:hyperliquid:TRX": 0, "exchange:hyperliquid:SOL": 2,
                             "exchange:hyperliquid:DOGE": 0, "exchange:hyperliquid:SAND": 0, "exchange:hyperliquid:NEO": 2,
                             "exchange:hyperliquid:RUNE": 1, "exchange:hyperliquid:ALGO": 0])
        #expect(try registry.decimals(of: AssetInstance(HyperliquidHolding.usdc)) == 6)
    }

    // Added in step 4c of the identity PR at the coordinator's word: the coins whose class the library already
    // declares, where the recorded mainnet `meta` states their size decimals.
    @Test func theRecordedMetaYieldsBNBAtThreePOLAtZeroAndTRXAtZeroDeclared() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let stated = Dictionary(uniqueKeysWithValues: Self.recordedCoins.map { ($0.name, $0.szDecimals) })
        #expect(stated["BNB"] == 3 && stated["POL"] == 0 && stated["TRX"] == 0)
        for (holding, decimals) in [(HyperliquidHolding.bnb, 3), (.pol, 0), (.trx, 0)] {
            let instance = try #require(try HyperliquidExchangeChain.declaredInstance(wireName: holding.wireName, decimals: decimals, in: registry))
            #expect(instance == AssetInstance(holding))
            #expect(try registry.decimals(of: instance) == decimals)
        }
    }

    @Test func bnbPOLAndTRXAreInstancesOfTheirChainsCoins() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let classes: [(HyperliquidHolding, AssetInstance, String)] = [
            (.bnb, EIP155.BinanceSmartChain.bnb.instance, "BNB"),
            (.pol, EIP155.Polygon.pol.instance, "POL"),
            (.trx, TRON.Tron.trx.instance, "TRX")
        ]
        for (holding, home, symbol) in classes {
            let instance = AssetInstance(holding)
            #expect(try registry.asset(of: instance) == registry.asset(of: home))
            #expect(try registry.isEquivalent(instance, home))
            let declared = try #require(try registry.declaration(of: registry.asset(of: home)).instances.first { $0.instance == instance })
            #expect(declared.symbol.text == symbol)
        }
    }

    // Added 2026-10-09: the suite's picks the testnet refused `assetNotDeclared` (ALGO, DOGE) and their companions, each
    // the instance on Hyperliquid of its class's home, at the size decimals both networks' `meta` state.
    static let fiveHoldings: [(holding: HyperliquidHolding, home: AssetInstance, decimals: Int, symbol: String)] = [
        (.doge, BIP122.Dogecoin.doge.instance, 0, "DOGE"),
        (.sand, EIP155.Ethereum.theSandbox.instance, 0, "SAND"),
        (.neo, NEO.Neo.neo.instance, 2, "NEO"),
        (.rune, COSMOS.THORChain.rune.instance, 1, "RUNE"),
        (.algo, ALGORAND.Algorand.algo.instance, 0, "ALGO")
    ]

    @Test func dogeSANDNEORUNEAndALGOResolveThroughTheirClassesOnHyperliquid() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        for (holding, home, decimals, symbol) in Self.fiveHoldings {
            let asset = try registry.asset(of: home)
            let instance = try registry.instance(of: asset, on: EXCHANGE.Hyperliquid.chainId)
            #expect(instance == AssetInstance(holding))
            #expect(try registry.decimals(of: instance) == decimals)
            #expect(try registry.isEquivalent(instance, home))
            let declared = try #require(try registry.declaration(of: asset).instances.first { $0.instance == instance })
            #expect(declared.symbol.text == symbol)
            #expect(holding.wireName == symbol)
        }
    }

    @Test func theRecordedMetaStatesTheFivesDeclaredDecimals() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let stated = Dictionary(uniqueKeysWithValues: Self.recordedCoins.map { ($0.name, $0.szDecimals) })
        for (holding, _, decimals, _) in Self.fiveHoldings {
            #expect(stated[holding.wireName] == decimals)
            let instance = try #require(try HyperliquidExchangeChain.declaredInstance(wireName: holding.wireName, decimals: decimals, in: registry))
            #expect(instance == AssetInstance(holding))
        }
    }

    @Test func btcsClassIsBitcoinAndUSDCsIsUSDCoin() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let btc = AssetInstance(HyperliquidHolding.btc)
        #expect(try registry.asset(of: btc) == .btc)
        #expect(try registry.instance(of: .btc, on: EXCHANGE.Hyperliquid.chainId) == btc)
        let declared = try #require(try registry.declaration(of: .btc).instances.first { $0.instance == btc })
        #expect(declared.symbol.text == "BTC")
        #expect(try registry.asset(of: AssetInstance(HyperliquidHolding.usdc)) == .usdc)
        #expect(try registry.asset(of: AssetInstance(HyperliquidHolding.eth)) == .eth)
    }

    @Test func declaringTwiceIsDeclaringOnce() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        try HyperliquidExchangeChain.declare(in: registry)
        #expect(try registry.decimals(of: AssetInstance(HyperliquidHolding.btc)) == 5)
        #expect(try registry.declaration(of: .btc).instances.count == 2)
    }

    // SOL now has its class (Solana admitted), so the example of a holding with no class is kPEPE alone
    @Test func aHoldingWithNoDeclaredClassIsNoInstance() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        #expect(try HyperliquidExchangeChain.declaredInstance(wireName: "kPEPE", decimals: 0, in: registry) == nil)
    }

    @Test func solIsDeclaredInSolanasClass() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let sol = try #require(try HyperliquidExchangeChain.declaredInstance(wireName: "SOL", decimals: 2, in: registry))
        #expect(sol == AssetInstance(HyperliquidHolding.sol))
        #expect(sol.id == "exchange:hyperliquid:SOL")
        #expect(try registry.asset(of: sol) == registry.asset(of: SOLANA.Solana.sol.instance))
    }

    @Test func anAccountOnHyperliquidIsNoInstance() throws {
        let registry = try Self.registry()
        try HyperliquidExchangeChain.declare(in: registry)
        let account = AssetInstance(HyperliquidHolding(address: "four-hour-2x"))
        #expect(account.id == "exchange:hyperliquid:four-hour-2x")
        #expect(throws: AssetRegistryError.undeclaredInstance(account)) { try registry.asset(of: account) }
    }

    @Test func theDeclaredChainIsKnownToBlockChains() throws {
        try HyperliquidExchangeChain.declare(in: Self.registry())
        #expect(BlockChains.contract(of: AssetInstance(HyperliquidHolding.btc)) as? HyperliquidHolding == HyperliquidHolding.btc)
    }

    // MARK: The units check (AR45) and the candle client

    @Test func aRecordedCandleLandsOnBTCAndUSDC() async throws {
        let session = ReplaySession(route: HyperliquidOHLCVClientContractTests.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let first = try #require(try await HyperliquidOHLCVClientContractTests.client(session)
            .ohlcv(market: HyperliquidOHLCVClientContractTests.btc, interval: Feed.day,
                   from: HyperliquidOHLCVClientContractTests.from, through: HyperliquidOHLCVClientContractTests.through).first)
        #expect(first.open.base == AssetInstance(HyperliquidHolding.btc))
        #expect(first.open.quote == AssetInstance(HyperliquidHolding.usdc))
        #expect(first.volume.instance == AssetInstance(HyperliquidHolding.btc))
    }

    @Test func aRecordedMetaWithBTCAtFourRaisesTheUnitsFinding() async throws {
        let meta = String(decoding: Feed.body("Hyperliquid/meta.json"), as: UTF8.self)
            .replacingOccurrences(of: #"{"szDecimals":5,"name":"BTC""#, with: #"{"szDecimals":4,"name":"BTC""#)
        #expect(meta.contains(#"{"szDecimals":4,"name":"BTC""#))
        let session = ReplaySession { request, _ in
            request.jsonBody["type"] as? String == "meta" ? .ok(Data(meta.utf8)) : .ok(Feed.body("Hyperliquid/candles-btc-1d.json"))
        }
        await #expect(throws: AssetRegistryError.decimalsChanged(AssetInstance(HyperliquidHolding.btc))) {
            try await HyperliquidOHLCVClient(session: session, now: { Feed.hyperliquidRecordedAt }, registry: Self.registry())
                .ohlcv(market: HyperliquidOHLCVClientContractTests.btc, interval: Feed.day,
                       from: HyperliquidOHLCVClientContractTests.from, through: HyperliquidOHLCVClientContractTests.through)
        }
    }

    @Test func anUndeclaredCoinIsAMarketTheCandleClientCannotPrice() async throws {
        let session = ReplaySession(route: HyperliquidOHLCVClientContractTests.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let kPEPE = try HyperliquidMarketName(validating: HyperliquidHolding.kPEPE.wireName)
        await #expect(throws: HyperliquidOHLCVError.unknownMarket(kPEPE)) {
            try await HyperliquidOHLCVClientContractTests.client(session)
                .ohlcv(market: kPEPE, interval: Feed.day, from: HyperliquidOHLCVClientContractTests.from, through: HyperliquidOHLCVClientContractTests.through)
        }
    }

    @Test func theCandleClientDeclaresHyperliquidInItsRegistry() throws {
        let registry = try Self.registry()
        _ = HyperliquidOHLCVClient(session: ReplaySession(route: HyperliquidOHLCVClientContractTests.route(candles: "Hyperliquid/candles-btc-1d.json")),
                                   registry: registry)
        #expect(try registry.decimals(of: AssetInstance(HyperliquidHolding.usdc)) == 6)
    }

    // MARK: The scanner, unconfigured

    @Test func anUnconfiguredScannerThrowsAndIsNotAvailable() async throws {
        let scanner = HyperliquidScanner()
        #expect(!scanner.isAvailable)
        #expect(scanner.userReadableName == "Hyperliquid")
        do {
            _ = try await scanner.getBalance(forAccount: .stub())
            Issue.record("An unconfigured scanner answered")
        } catch let error as ExchangeClientError {
            guard case .unauthorized(let text) = error else {
                Issue.record("Not unauthorized: \(error)")
                return
            }
            #expect(text.contains("Hyperliquid"))
        }
        await #expect(throws: ExchangeClientError.self) { try await scanner.getTransactions(forAccount: .stub()) }
    }
}
