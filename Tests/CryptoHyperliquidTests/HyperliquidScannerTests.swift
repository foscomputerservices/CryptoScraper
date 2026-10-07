// HyperliquidScannerTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
@testable import CryptoHyperliquid
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// Design § 1.3 "Never nil" and § 6 "The exchange scanners" and "The table, per plug-in", for Hyperliquid: the scanner
// configured over a client whose answers are the recordings, the client's declarations and its units check, and the
// recorded listing through the table. Each scanner is made fresh, so no test reads another's configuration.
//
// The owner's recorded sub-account holds positions and fills in coins no class declares (NEO, RUNE, ALGO; BNB has been
// declared since step 4c of the identity PR), and a money value in an undeclared holding is refused (design § 5.3). So
// the reads of a position and of a fill run over the same recordings with the other coins' rows taken out, and one test
// states the refusal over the whole.

@Suite("Hyperliquid's scanner and holdings")
struct HyperliquidScannerTests {
    static let btc = AssetInstance(HyperliquidHolding.btc)
    static let usdc = AssetInstance(HyperliquidHolding.usdc)

    // The recorded answer for `file` with only the rows whose coin is in `coins` kept: `assetPositions` for a
    // clearinghouse state, the list itself for fills.
    static func kept(_ file: String, coins: Set<String>) -> Data {
        let json = Recording.json("Hyperliquid/\(file)")
        let kept: Any
        if var state = json as? [String: Any] {
            state["assetPositions"] = (state["assetPositions"] as! [[String: Any]]).filter {
                coins.contains(($0["position"] as! [String: Any])["coin"] as! String)
            }
            kept = state
        } else {
            kept = (json as! [[String: Any]]).filter { coins.contains($0["coin"] as! String) }
        }
        return try! JSONSerialization.data(withJSONObject: kept)
    }

    // The recordings, the sub-account's positions and fills kept to its declared coin, ETH.
    static func declaredOnlyRoute(coins: Set<String> = ["ETH"]) -> @Sendable (URLRequest, Int) -> Reply {
        let positions = kept("clearinghouse-sub.json", coins: coins)
        let fills = kept("fills-sub.json", coins: coins)
        return { request, index in
            let body = request.jsonBody
            switch body["type"] as? String {
            case "clearinghouseState" where (body["user"] as? String) != Hyperliquid.master: return .ok(positions)
            case "userFillsByTime": return .ok(fills)
            default: return Hyperliquid.route()(request, index)
            }
        }
    }

    static func configured(_ route: @escaping @Sendable (URLRequest, Int) -> Reply = Hyperliquid.route()) -> HyperliquidScanner {
        let scanner = HyperliquidScanner()
        scanner.configure(client: Hyperliquid.client(ReplaySession(route: route)))
        return scanner
    }

    // MARK: The scanner over the recordings

    @Test func aConfiguredScannerIsAvailable() {
        #expect(Self.configured().isAvailable)
    }

    @Test func theClientConfiguresItselfIntoTheChainsScanner() {
        _ = Hyperliquid.client(ReplaySession(route: Hyperliquid.route()))
        #expect(HyperliquidExchangeChain.default.scanner.isAvailable)
    }

    @Test func theBalanceIsTheRecordedAccountStatesBalance() async throws {
        let balance = try await Self.configured().getBalance(forAccount: .init(address: Hyperliquid.master))
        // clearinghouse-master: accountValue "421.2", in Hyperliquid's USDC at six places
        #expect(balance.quantity == 421_200_000)
        #expect(balance.currency == HyperliquidHolding.usdc)
    }

    @Test func theUSDCsBalanceIsTheAccountsBalance() async throws {
        let balance = try await Self.configured().getBalance(forToken: .usdc, forAccount: .init(address: Hyperliquid.master))
        #expect(balance.quantity == 421_200_000 && balance.currency == HyperliquidHolding.usdc)
    }

    @Test func aHoldingsBalanceIsTheUnitsOfItsPositions() async throws {
        let balance = try await Self.configured(Self.declaredOnlyRoute()).getBalance(forToken: .eth, forAccount: .init(address: "four-hour-2x"))
        // The recorded ETH position: szi "0.0088", a long, at ETH's four places
        #expect(balance.quantity == 88)
        #expect(balance.currency == HyperliquidHolding.eth)
    }

    @Test func aHoldingWithNoPositionIsZero() async throws {
        let balance = try await Self.configured().getBalance(forToken: .btc, forAccount: .init(address: Hyperliquid.master))
        #expect(balance.quantity == 0 && balance.currency == HyperliquidHolding.btc)
    }

    // Added in step 4c of the identity PR: Hyperliquid's BNB is declared (BNB Smart Chain's coin's class, at the 3 size
    // decimals the recorded `meta` states), so the recorded sub-account's BNB position is read.
    @Test func theRecordedBNBPositionIsReadInTheBNBHolding() async throws {
        let route = Self.declaredOnlyRoute(coins: ["ETH", "BNB"])
        let balance = try await Self.configured(route).getBalance(forToken: .bnb, forAccount: .init(address: "four-hour-2x"))
        // The recorded BNB position: szi "0.027", a long, at BNB's three places
        #expect(balance.quantity == 27)
        #expect(balance.currency == HyperliquidHolding.bnb)
    }

    @Test func aPositionInAnUndeclaredHoldingIsRefused() async throws {
        // The recorded sub-account's third position is NEO's: no class declares Hyperliquid's NEO. (Carried in step 4c
        // of the identity PR: its second, BNB's, is declared now.)
        let error = await sharedError { try await Hyperliquid.client(ReplaySession(route: Hyperliquid.route())).accountState(account: "four-hour-2x") }
        #expect(error == .refused(code: nil, text: "Hyperliquid's NEO is no declared holding"))
    }

    @Test func theLedgerMapsEachItemToAHyperliquidTransaction() async throws {
        let transactions = try await Self.configured(Self.declaredOnlyRoute()).getTransactions(forAccount: .init(address: "four-hour-2x"))
        let items = try #require(transactions as? [HyperliquidTransaction])
        // ETH's 11 recorded fills, the 500 funding payments, the 4 moves of USDC
        #expect(items.count == 11 + 500 + 4)
        let fills = items.filter { $0.type == "fill" }
        #expect(fills.count == 11 && fills.allSatisfy { $0.amount.currency == HyperliquidHolding.eth })
        #expect(items.filter { $0.type != "fill" }.allSatisfy { $0.amount.currency == HyperliquidHolding.usdc })
        // The first ETH fill: sz "0.008" at ETH's four places, oid 61246678885, at 1790568059898
        let first = try #require(fills.first)
        #expect(first.amount.quantity == 80)
        #expect(first.transactionId == "61246678885" && first.hash == first.transactionId)
        #expect(first.timeStamp == Date(wireMilliseconds: 1_790_568_059_898))
        #expect(items.allSatisfy { $0.successful })
        #expect(items.map(\.timeStamp) == items.map(\.timeStamp).sorted())
    }

    @Test func loadingTheRecordedTransactionsGivesTheSameList() async throws {
        let scanner = Self.configured(Self.declaredOnlyRoute())
        let read = try #require(try await scanner.getTransactions(forAccount: .init(address: "four-hour-2x")) as? [HyperliquidTransaction])
        let loaded = try #require(try scanner.loadTransactions(from: JSONEncoder().encode(read)) as? [HyperliquidTransaction])
        #expect(loaded == read)
    }

    @Test func theChainsScannerIsHyperliquids() {
        #expect(HyperliquidExchangeChain.default.scanner.userReadableName == "Hyperliquid")
    }

    // MARK: The client's holdings

    @Test func theClientDeclaresHyperliquidInItsRegistry() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        _ = HyperliquidClient(credential: nil, endpoint: .testMarket, session: ReplaySession(route: Hyperliquid.route()), registry: registry)
        #expect(try registry.decimals(of: Self.btc) == 5)
        #expect(try registry.asset(of: Self.btc) == .btc)
        #expect(try registry.decimals(of: Self.usdc) == 6)
    }

    @Test func everyCoinTheRecordedAccountTouchesResolvesOrIsAFinding() throws {
        let fills = Recording.json("Hyperliquid/fills-sub.json") as! [[String: Any]]
        let coins = Set(fills.map { $0["coin"] as! String })
        #expect(coins == ["ALGO", "BNB", "ETH", "NEO", "RUNE"])
        #expect(try HyperliquidExchangeChain.default.contract(for: "ETH") == HyperliquidHolding.eth)
        // Carried in step 4c of the identity PR: BNB joined the table.
        #expect(try HyperliquidExchangeChain.default.contract(for: "BNB") == HyperliquidHolding.bnb)
        for coin in coins.subtracting(["ETH", "BNB"]) {
            #expect(throws: AssetError.malformedIdentity(coin)) { try HyperliquidExchangeChain.default.contract(for: coin) }
        }
    }

    @Test func btcsWireNameIsTheCoinTheRecordedBookAsks() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        _ = try await Hyperliquid.client(session).orderBook(market: try HyperliquidMarketName(validating: HyperliquidHolding.btc.wireName))
        let asked = try #require(session.requests.first { $0.jsonBody["type"] as? String == "l2Book" })
        #expect(asked.jsonBody["coin"] as? String == HyperliquidHolding.btc.wireName)
        #expect(Recording.json("Hyperliquid/l2book-btc.json") as? [String: Any] != nil)
    }

    @Test func aRecordedMarketLandsOnBTCAndUSDCWithBTCAtFiveAsItsLot() async throws {
        let markets = try await Hyperliquid.client(ReplaySession(route: Hyperliquid.route())).markets()
        let btc = try #require(markets.first { $0.name == Hyperliquid.btc })
        #expect(btc.base == Self.btc && btc.quote == Self.usdc)
        #expect(btc.baseSymbol.text == "BTC" && btc.baseDecimals == 5)
        #expect(btc.quoteSymbol.text == "USDC" && btc.quoteDecimals == 6)
        // One base unit of BTC at 5 is the lot; the $10 minimum is in Hyperliquid's USDC
        #expect(btc.lotSize == Amount(baseUnits: 1, of: Self.btc))
        #expect(btc.minimumOrder == Amount(baseUnits: 10_000_000, of: Self.usdc))
        #expect(btc.alternateName == nil)
    }

    @Test func kPEPEIsListedWithNilHoldingAndNoLot() async throws {
        let markets = try await Hyperliquid.client(ReplaySession(route: Hyperliquid.route())).markets()
        let kPEPE = try #require(markets.first { $0.name == (try! HyperliquidMarketName(validating: "kPEPE")) })
        #expect(kPEPE.base == nil && kPEPE.lotSize == nil)
        #expect(kPEPE.quote == Self.usdc)
        #expect(kPEPE.baseSymbol.text == "KPEPE" && kPEPE.baseDecimals == 0)
    }

    @Test func aRecordedMetaWithBTCAtFourIsRefusedAsTheUnitsFinding() async throws {
        let meta = String(decoding: Recording.body("Hyperliquid/meta.json"), as: UTF8.self)
            .replacingOccurrences(of: #"{"szDecimals":5,"name":"BTC""#, with: #"{"szDecimals":4,"name":"BTC""#)
        #expect(meta.contains(#"{"szDecimals":4,"name":"BTC""#))
        let session = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "meta" ? .ok(Data(meta.utf8)) : Hyperliquid.route()(request, index)
        }
        let error = await sharedError { try await Hyperliquid.client(session).markets() }
        guard case .refused(nil, let text) = error else {
            Issue.record("Not the units finding: \(String(describing: error))")
            return
        }
        #expect(text.contains("decimalsChanged") && text.contains("exchange:hyperliquid:BTC"))
    }
}
