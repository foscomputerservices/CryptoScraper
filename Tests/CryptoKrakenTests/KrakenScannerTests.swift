// KrakenScannerTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
@testable import CryptoKraken
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// Design § 1.3 "Never nil" and § 6 "The exchange scanners" and "The table, per plug-in", for Kraken: the scanner
// configured over a client whose answers are the recordings, the client's declarations and its units check, and the
// recorded listing through the table. Each scanner is made fresh, so no test reads another's configuration.

@Suite("Kraken's scanner and holdings")
struct KrakenScannerTests {
    static func configured() -> KrakenScanner {
        let scanner = KrakenScanner()
        scanner.configure(client: Kraken.client(ReplaySession(route: Kraken.route())))
        return scanner
    }

    // MARK: The scanner over the recordings

    @Test func aConfiguredScannerIsAvailable() {
        #expect(Self.configured().isAvailable)
    }

    @Test func theClientConfiguresItselfIntoTheChainsScanner() {
        _ = Kraken.client(ReplaySession(route: Kraken.route()))
        #expect(KrakenExchangeChain.default.scanner.isAvailable)
    }

    @Test func theBalanceIsTheRecordedAccountStatesBalance() async throws {
        let balance = try await Self.configured().getBalance(forAccount: .stub())
        // TradeBalance's "eb": "1101.3425", in Kraken's dollar at four places
        #expect(balance.quantity == 11_013_425)
        #expect(balance.currency == KrakenHolding.usd)
    }

    @Test func theDollarsBalanceIsTheAccountsBalance() async throws {
        let balance = try await Self.configured().getBalance(forToken: .usd, forAccount: .stub())
        #expect(balance.quantity == 11_013_425 && balance.currency == KrakenHolding.usd)
    }

    @Test func aHoldingsBalanceIsTheUnitsOfItsPositions() async throws {
        let balance = try await Self.configured().getBalance(forToken: .xbt, forAccount: .stub())
        // The recorded open positions, all buys of XXBTZUSD, vol less vol_closed: 8.62212861 + 8 + 0.0000001 + 0.0001
        // + 0.0008999 = 16.62312861 bitcoin, at Kraken's ten places
        #expect(balance.quantity == 166_231_286_100)
        #expect(balance.currency == KrakenHolding.xbt)
    }

    @Test func aHoldingWithNoPositionIsZero() async throws {
        let balance = try await Self.configured().getBalance(forToken: .eth, forAccount: .stub())
        #expect(balance.quantity == 0 && balance.currency == KrakenHolding.eth)
    }

    @Test func theLedgerMapsEachItemToAKrakenTransaction() async throws {
        let transactions = try await Self.configured().getTransactions(forAccount: .stub())
        let fills = try #require(transactions as? [KrakenTransaction])
        #expect(fills.count == 2)
        // The recorded trades in time order: TCWJEG at 1688667769.6396 for 0.01, THVRQM at 1688667796.8802 for 0.02
        #expect(fills.map(\.amount.quantity) == [100_000_000, 200_000_000])
        #expect(fills.allSatisfy { $0.amount.currency == KrakenHolding.xbt })
        #expect(fills.map(\.timeStamp) == [KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667769.6396")).time,
                                           KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667796.8802")).time])
        #expect(fills.allSatisfy { $0.transactionId == "OQCLML-BW3P3-BUCMWZ" && $0.hash == $0.transactionId })
        #expect(fills.allSatisfy { $0.type == "fill" && $0.successful && $0.fromContract == nil && $0.toContract == nil })
    }

    @Test func loadingTheRecordedTransactionsGivesTheSameList() async throws {
        let scanner = Self.configured()
        let read = try #require(try await scanner.getTransactions(forAccount: .stub()) as? [KrakenTransaction])
        let loaded = try #require(try scanner.loadTransactions(from: JSONEncoder().encode(read)) as? [KrakenTransaction])
        #expect(loaded == read)
    }

    @Test func theChainsScannerIsKrakens() {
        #expect(KrakenExchangeChain.default.scanner.userReadableName == "Kraken")
    }

    // MARK: The client's holdings

    @Test func theClientDeclaresKrakenInItsRegistry() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        _ = KrakenClient(credential: Kraken.credential, session: ReplaySession(route: Kraken.route()), registry: registry)
        #expect(try registry.decimals(of: AssetInstance(KrakenHolding.xbt)) == 10)
        #expect(try registry.asset(of: AssetInstance(KrakenHolding.xbt)) == .btc)
    }

    @Test func everyWireNameInTheRecordedListingResolvesOrIsAFinding() throws {
        let pairs = (Recording.json("Kraken/asset-pairs.json") as! [String: Any])["result"] as! [String: [String: Any]]
        for name in pairs.values.flatMap({ [$0["base"] as! String, $0["quote"] as! String] }) {
            #expect(throws: Never.self) { try KrakenExchangeChain.default.contract(for: name) }
        }
        // The recorded ledger's pound is a name the table lacks: a finding, never a holding minted from the string
        let ledger = (Recording.json("Kraken/private-ledgers.json") as! [String: Any])["result"] as! [String: Any]
        let assets = Set(((ledger["ledger"] as! [String: [String: Any]]).values).map { $0["asset"] as! String })
        #expect(assets == ["ZGBP", "ZUSD"])
        #expect(throws: AssetError.malformedIdentity("ZGBP")) { try KrakenExchangeChain.default.contract(for: "ZGBP") }
    }

    @Test func xbtsWireNameIsWhatTheRecordedOrderSends() async throws {
        let queried = String(decoding: Recording.body("Kraken/private-query-orders.json"), as: UTF8.self)
            .replacingOccurrences(of: "OBCMZD-JIEE7-77TH3F", with: "OUF4EM-FRGI2-MQMWZD")
        let session = ReplaySession(route: Kraken.route(["QueryOrders": .ok(Data(queried.utf8))]))
        let size = try WireDecimal(parsing: "1.25").amount(of: Kraken.declared(.xbt))
        let pair = try KrakenMarketName(validating: KrakenHolding.xbt.wireName + KrakenHolding.usd.wireName)
        _ = try await Kraken.client(session).placeOrder(market: pair, side: .buy, size: size, limit: Kraken.price("27600"),
                                                        immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "")
        let added = try #require(session.requests.first { $0.url!.lastPathComponent == "AddOrder" })
        #expect(added.bodyText.contains("&pair=\(KrakenHolding.xbt.wireName)\(KrakenHolding.usd.wireName)&"))
        // and the recorded order's own description names its pair the same way
        #expect(queried.contains(#""pair": "XBTUSD""#))
    }

    @Test func aRecordedMarketLandsOnXBTAndUSD() async throws {
        let markets = try await Kraken.client(ReplaySession(route: Kraken.route())).markets()
        let xbt = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "XXBTZUSD")) })
        #expect(xbt.base == AssetInstance(KrakenHolding.xbt) && xbt.quote == AssetInstance(KrakenHolding.usd))
        #expect(xbt.baseSymbol.text == "XBT" && xbt.baseDecimals == 10)
        #expect(xbt.quoteSymbol.text == "USD" && xbt.quoteDecimals == 4)
    }

    // Every asset of Kraken's recorded answers now has its class (Solana admitted), so the undeclared base is the
    // recorded answers' SOL renamed FRED, an asset Kraken's table does not list
    @Test func anUndeclaredBaseGivesAMarketWithNilAmounts() async throws {
        func renamed(_ file: String) -> Reply {
            .ok(Data(String(decoding: Recording.body("Kraken/\(file)"), as: UTF8.self)
                .replacingOccurrences(of: "SOL", with: "FRED").utf8))
        }
        let session = ReplaySession(route: Kraken.route(["Assets": renamed("assets.json"), "AssetPairs": renamed("asset-pairs.json")]))
        let markets = try await Kraken.client(session).markets()
        let fred = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "FREDUSD")) })
        #expect(fred.base == nil && fred.lotSize == nil && fred.minimumOrder == nil)
        #expect(fred.quote == AssetInstance(KrakenHolding.usd))
        #expect(fred.baseSymbol.text == "FRED" && fred.baseDecimals == 10)
    }

    @Test func solsMarketNamesItsDeclaredHolding() async throws {
        let markets = try await Kraken.client(ReplaySession(route: Kraken.route())).markets()
        let sol = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "SOLUSD")) })
        #expect(sol.base == AssetInstance(KrakenHolding.sol))
        #expect(sol.lotSize != nil)
    }

    @Test func aRecordedAnswerWithXBTAtEightIsRefusedAsTheUnitsFinding() async throws {
        let assets = String(decoding: Recording.body("Kraken/assets.json"), as: UTF8.self)
            .replacingOccurrences(of: #""altname":"XBT","decimals":10"#, with: #""altname":"XBT","decimals":8"#)
        #expect(assets.contains(#""decimals":8"#))
        let session = ReplaySession(route: Kraken.route(["Assets": .ok(Data(assets.utf8))]))
        let error = await sharedError { try await Kraken.client(session).markets() }
        guard case .refused(nil, let text) = error else {
            Issue.record("Not the units finding: \(String(describing: error))")
            return
        }
        #expect(text.contains("decimalsChanged") && text.contains("exchange:kraken:XBT"))
    }
}
