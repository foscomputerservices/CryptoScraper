// KrakenClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
@testable import CryptoKraken
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// § 8.6 for Kraken's exchange client: the public reads recorded read-only on 2026-10-06; the private answers are
// Kraken's documented examples (no Kraken account exists here), each marked documentation-derived in its header;
// the signing against Kraken's own documented vector (AR32).

enum Kraken {
    static let xbtusd = try! KrakenMarketName(validating: "XBTUSD")
    // Kraken's declared holdings (step 4a of the identity PR), declared in the shared registry before any amount is
    // made in them, whichever test runs first
    static let xbt: AssetInstance = declared(KrakenHolding.xbt)
    static let usd: AssetInstance = declared(KrakenHolding.usd)
    static let credential = try! KrakenCredential(apiKey: "FRED-KEY", base64Secret: "kQH5HW/8p1uGOVjbgWA7FunAmGO8lsSUXNsu3eow76sz84Q18fWxnyRzBHCd3pd5nE9qa99HAZtuZuj6F1huXg==")
    static let now = Date(timeIntervalSince1970: 1_791_272_956)

    static func route(_ overrides: [String: Reply] = [:]) -> @Sendable (URLRequest, Int) -> Reply {
        { request, _ in
            let method = request.url!.lastPathComponent
            if let reply = overrides[method] { return reply }
            let file: String = switch method {
            case "AssetPairs": "asset-pairs.json"
            case "Assets": "assets.json"
            case "Ticker": "ticker-xbtusd.json"
            case "upcoming.json": "maintenances-upcoming.json"
            case "TradeBalance": "private-trade-balance.json"
            case "OpenOrders": "private-open-orders.json"
            case "QueryOrders": "private-query-orders.json"
            case "AddOrder": "private-add-order.json"
            case "CancelOrder": "private-cancel-order.json"
            case "TradesHistory": "private-trades-history.json"
            case "Ledgers": "private-ledgers.json"
            case "OpenPositions": "private-open-positions.json"
            default: "none"
            }
            return .ok(Recording.body("Kraken/\(file)"))
        }
    }

    static func client(_ session: ReplaySession) -> KrakenClient {
        KrakenClient(credential: credential, session: session, now: { now })
    }

    static func declared(_ holding: KrakenHolding) -> AssetInstance {
        do {
            try KrakenExchangeChain.declare(in: .shared)
        } catch {
            preconditionFailure("Kraken's declarations conflict with the shared registry: \(error)")
        }
        return AssetInstance(holding)
    }

    static func price(_ text: String) -> Price {
        try! WireDecimal(parsing: text).price(of: usd, per: xbt)
    }
}

@Suite("Kraken exchange client")
struct KrakenClientTests {
    @Test func theSignatureIsKrakensDocumentedExample() {
        // https://docs.kraken.com/api/docs/guides/spot-rest-auth, the worked example, verbatim.
        let body = "nonce=1616492376594&ordertype=limit&pair=XBTUSD&price=37500&type=buy&volume=1.25"
        let secret = Data(base64Encoded: "kQH5HW/8p1uGOVjbgWA7FunAmGO8lsSUXNsu3eow76sz84Q18fWxnyRzBHCd3pd5nE9qa99HAZtuZuj6F1huXg==")!
        #expect(KrakenClient.signature(path: "/0/private/AddOrder", nonce: "1616492376594", body: body, secret: secret)
            == "4/dpxb3iT4tp/ZCVEwSnEsLxx0bqyhLpdfOpc6fn7OR8+UClSV5n9E6aSS8MPtnRfp32bAb0nmbRn6H8ndwLUQ==")
    }

    @Test func aPrivateRequestCarriesTheKeyTheSignatureAndTheNonceFirst() async throws {
        let session = ReplaySession(route: Kraken.route())
        _ = try await Kraken.client(session).openOrders(account: "")
        let sent = try #require(session.requests.first { $0.url!.path == "/0/private/OpenOrders" })
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "API-Key") == "FRED-KEY")
        #expect(sent.bodyText == "nonce=1791272956000")
        let expected = KrakenClient.signature(path: "/0/private/OpenOrders", nonce: "1791272956000", body: "nonce=1791272956000",
                                              secret: Data(base64Encoded: "kQH5HW/8p1uGOVjbgWA7FunAmGO8lsSUXNsu3eow76sz84Q18fWxnyRzBHCd3pd5nE9qa99HAZtuZuj6F1huXg==")!)
        #expect(sent.value(forHTTPHeaderField: "API-Sign") == expected)
    }

    @Test func theCredentialNamesNeitherItsKeyNorItsSecret() {
        for text in [Kraken.credential.description, String(reflecting: Kraken.credential), "\(Kraken.credential)"] {
            #expect(!text.contains("FRED-KEY") && !text.contains("kQH5HW"))
        }
        #expect(throws: ExchangeClientError.unauthorized(text: "A Kraken API key and its base64 secret are both needed")) { try KrakenCredential(apiKey: "k", base64Secret: "not base64!") }
    }

    @Test func theMarketsAreKrakensPairsWithTheirLotsMinimumsAndLeverage() async throws {
        let session = ReplaySession(route: Kraken.route())
        let markets = try await Kraken.client(session).markets()
        #expect(markets.count == 3)
        let xbt = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "XXBTZUSD")) })
        #expect(xbt.base == Kraken.xbt && xbt.quote == Kraken.usd)
        #expect(xbt.lotSize == Amount(baseUnits: 100, of: Kraken.xbt))           // lot_decimals 8 at decimals 10
        #expect(xbt.minimumOrder == Amount(baseUnits: 500_000, of: Kraken.xbt))  // ordermin "0.00005"
        #expect(xbt.maxLeverage == 10)
        #expect(!xbt.isPerpetual)
    }

    // Step 4b of the identity PR: C30's market carries Kraken's second name for a pair, the one it accepts beside its key.
    @Test func aRecordedPairCarriesBothOfKrakensNames() async throws {
        let markets = try await Kraken.client(ReplaySession(route: Kraken.route())).markets()
        let xbt = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "XXBTZUSD")) })
        #expect(xbt.alternateName == (try KrakenMarketName(validating: "XBTUSD")))
        let eth = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "XETHZUSD")) })
        #expect(eth.alternateName == (try KrakenMarketName(validating: "ETHUSD")))
        // Kraken writes SOLUSD's key and its alternative name alike: one name
        let sol = try #require(markets.first { $0.name == (try! KrakenMarketName(validating: "SOLUSD")) })
        #expect(sol.alternateName == nil)
    }

    @Test func theBookIsTheTickersBestBidAndAskTheirMidAndTheDaysVolume() async throws {
        let session = ReplaySession(route: Kraken.route())
        let book = try await Kraken.client(session).orderBook(market: Kraken.xbtusd)
        #expect(book.bestAsk == Kraken.price("85554.6"))
        #expect(book.bestBid == Kraken.price("85554.5"))
        #expect(book.mid == Kraken.price("85554.55"))
        #expect(book.baseVolume == (try WireDecimal(parsing: "2101.23007377").amount(of: Kraken.xbt)))
        // Kraken publishes no quote turnover: v[1] × the mid, 179769793.4078591535, cut toward zero at USD's four digits
        #expect(book.quoteVolume == (try WireDecimal(parsing: "179769793.4078").amount(of: Kraken.usd)))
    }

    @Test func aFilledOrderIsQueriedForItsUnitsAndPrice() async throws {
        let queried = String(decoding: Recording.body("Kraken/private-query-orders.json"), as: UTF8.self)
            .replacingOccurrences(of: "OBCMZD-JIEE7-77TH3F", with: "OUF4EM-FRGI2-MQMWZD")
        let session = ReplaySession(route: Kraken.route(["QueryOrders": .ok(Data(queried.utf8))]))
        let size = try WireDecimal(parsing: "1.25").amount(of: Kraken.xbt)
        let result = try await Kraken.client(session).placeOrder(market: Kraken.xbtusd, side: .buy, size: size, limit: Kraken.price("27600"),
                                                                  immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "")
        let id = try KrakenOrderId(validating: "OUF4EM-FRGI2-MQMWZD")
        #expect(result == .filled(units: size, at: Kraken.price("27500"), id: id, time: Date(timeIntervalSince1970: 1_688_665_499.1922)))
        let added = try #require(session.requests.first { $0.url!.lastPathComponent == "AddOrder" })
        #expect(added.bodyText == "nonce=1791272956000&ordertype=limit&type=buy&volume=1.25&pair=XBTUSD&price=27600&timeinforce=IOC")
    }

    @Test func anOpenOrderWithNothingExecutedIsResting() async throws {
        let queried = String(decoding: Recording.body("Kraken/private-query-orders.json"), as: UTF8.self)
            .replacingOccurrences(of: "OBCMZD-JIEE7-77TH3F", with: "OUF4EM-FRGI2-MQMWZD")
            .replacingOccurrences(of: #""status": "closed""#, with: #""status": "open""#)
            .replacingOccurrences(of: #""vol_exec": "1.25000000""#, with: #""vol_exec": "0.00000000""#)
        let session = ReplaySession(route: Kraken.route(["QueryOrders": .ok(Data(queried.utf8))]))
        let size = try WireDecimal(parsing: "1.25").amount(of: Kraken.xbt)
        let result = try await Kraken.client(session).placeOrder(market: Kraken.xbtusd, side: .buy, size: size, limit: Kraken.price("27600"),
                                                                  immediateOrCancel: false, reduceOnly: false, clientOrderId: nil, account: "")
        let id = try KrakenOrderId(validating: "OUF4EM-FRGI2-MQMWZD")
        #expect(result == .resting(id: id, time: Date(timeIntervalSince1970: 1_688_665_499.1922)))
    }

    @Test func aRefusedOrderIsKrakensWords() async throws {
        let session = ReplaySession(route: Kraken.route(["AddOrder": .ok(Recording.body("Kraken/private-error-insufficient-funds.json"))]))
        let result = try await Kraken.client(session).placeOrder(market: Kraken.xbtusd, side: .sell, size: .zero(of: Kraken.xbt), limit: Kraken.price("1"),
                                                                  immediateOrCancel: true, reduceOnly: true, clientOrderId: nil, account: "")
        #expect(result == .refused(code: "EOrder", text: "Insufficient funds"))
    }

    @Test func anInvalidKeyIsUnauthorizedWithKrakensWords() async throws {
        let session = ReplaySession(route: Kraken.route(["OpenOrders": .ok(Recording.body("Kraken/private-error-invalid-key.json"))]))
        #expect(await sharedError { try await Kraken.client(session).openOrders(account: "") } == .unauthorized(text: "EAPI:Invalid key"))
    }

    @Test func aStatus401IsUnauthorized() async throws {
        let session = ReplaySession { _, _ in Reply(status: 401, body: Data(#"{"error":"authenticationError"}"#.utf8), headers: [:]) }
        #expect(await sharedError { try await Kraken.client(session).openOrders(account: "") }?.meaning == "unauthorized")
    }

    @Test func anErrorKrakenListsIsRefusedWithItsCodeAndItsText() async throws {
        let body = Data(#"{"error":["EGeneral:Invalid arguments:ordertype"],"result":{}}"#.utf8)
        let session = ReplaySession(route: Kraken.route(["OpenOrders": .ok(body)]))
        #expect(await sharedError { try await Kraken.client(session).openOrders(account: "") }
            == .refused(code: "EGeneral", text: "Invalid arguments:ordertype"))
    }

    @Test func aRateLimitInKrakensListIsRateLimitedWithNoWait() async throws {
        let session = ReplaySession(route: Kraken.route(["TradeBalance": .ok(Recording.body("Kraken/private-error-rate-limit.json"))]))
        #expect(await sharedError { try await Kraken.client(session).accountState(account: "") } == .rateLimited(retryAfter: nil))
    }

    @Test func a429WithRetryAfterIsRateLimitedWithItsWait() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "7"]) }
        #expect(await sharedError { try await Kraken.client(session).orderBook(market: Kraken.xbtusd) } == .rateLimited(retryAfter: .seconds(7)))
    }

    @Test func aMalformedBodyIsMalformedResponseNeverAValue() async throws {
        let session = ReplaySession(route: Kraken.route(["Ticker": .ok(Data(#"{"error":[],"result":{"XXBTZUSD":{"a":["eighty"],"b":["1"],"v":["1"]}}}"#.utf8))]))
        #expect(await sharedError { try await Kraken.client(session).orderBook(market: Kraken.xbtusd) }?.meaning == "malformedResponse")
    }

    @Test func aNumberFinerThanItsAssetFromKrakenIsMalformedResponse() async throws {
        let session = ReplaySession(route: Kraken.route(["TradeBalance": .ok(Data(#"{"error":[],"result":{"eb":"1.00000000000001","tb":"1","m":"0","n":"0","c":"0","v":"0","e":"0","mf":"0"}}"#.utf8))]))
        #expect(await sharedError { try await Kraken.client(session).accountState(account: "") }?.meaning == "malformedResponse")
    }

    @Test func noAnswerIsUnreachableWithTheTransportsText() async throws {
        let session = ReplaySession { _, _ in .failing(URLError(.timedOut)) }
        #expect(await sharedError { try await Kraken.client(session).orderBook(market: Kraken.xbtusd) } == .unreachable(text: URLError(.timedOut).localizedDescription))
    }

    @Test func theOpenOrdersAreTheirRemainingUnits() async throws {
        let session = ReplaySession(route: Kraken.route())
        let open = try await Kraken.client(session).openOrders(account: "")
        let first = try #require(open.first { $0.id == (try! KrakenOrderId(validating: "OQCLML-BW3P3-BUCMWZ")) })
        #expect(first.units == (try WireDecimal(parsing: "0.875").amount(of: Kraken.xbt)))
        #expect(first.side == .buy)
        #expect(open.count == 2)
    }

    @Test func aCancelIsOneOrderCancelled() async throws {
        let session = ReplaySession(route: Kraken.route())
        try await Kraken.client(session).cancelOrder(try KrakenOrderId(validating: "OQCLML-BW3P3-BUCMWZ"), market: Kraken.xbtusd, account: "")
        #expect(session.requests.last!.bodyText.hasSuffix("&txid=OQCLML-BW3P3-BUCMWZ"))
    }

    @Test func theAccountStateIsTheEquivalentBalanceTheFreeMarginAndThePositions() async throws {
        let session = ReplaySession(route: Kraken.route())
        let state = try await Kraken.client(session).accountState(account: "")
        #expect(state.balance == (try WireDecimal(parsing: "1101.3425").amount(of: Kraken.usd)))
        #expect(state.withdrawable == (try WireDecimal(parsing: "375.1678").amount(of: Kraken.usd)))
        let first = try #require(state.positions.first)
        #expect(first.market == (try KrakenMarketName(validating: "XXBTZUSD")))
        #expect(first.side == .buy)
        // TF5GVO-T7ZZ2-6NBKBI: cost "104610.52842" for vol "8.82412861", of which "0.20200000" closed; value "258797.5"
        let entry = Price(try WireDecimal(parsing: "1046105.2842").amount(of: Kraken.usd), per: try WireDecimal(parsing: "88.2412861").amount(of: Kraken.xbt))
        #expect(state.positions.contains { $0.entryPrice == entry })
        #expect(state.mode.name == "spot")
    }

    @Test func theLedgerIsTheTradesInTimeOrderEachWithItsExactCursor() async throws {
        let session = ReplaySession(route: Kraken.route())
        let items = try await Kraken.client(session).ledgerItems(account: "", since: nil)
        #expect(items.count == 2) // the two trades; the two ledger entries are those trades' and are not handed up twice
        guard case .fill(let market, let side, let units, let price, let fee, let order, _, _, let cursor, _) = items[0] else {
            Issue.record("Not a fill")
            return
        }
        #expect(market == (try KrakenMarketName(validating: "XXBTZUSD")) && side == .buy)
        #expect(units == (try WireDecimal(parsing: "0.01").amount(of: Kraken.xbt)))
        #expect(price == Kraken.price("30010"))
        #expect(fee == .zero(of: Kraken.usd))
        #expect(order == (try KrakenOrderId(validating: "OQCLML-BW3P3-BUCMWZ")))
        #expect(cursor == KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667769.6396"), read: [try KrakenLedgerId(validating: "TCWJEG-FL4SZ-3FKGH6")]))

        // Kraken's start is exclusive: the read asks from the ten-thousandth before the cursor's instant.
        let resumed = ReplaySession(route: Kraken.route())
        _ = try await Kraken.client(resumed).ledgerItems(account: "", since: cursor)
        for method in ["TradesHistory", "Ledgers"] {
            #expect(resumed.requests.first { $0.url!.lastPathComponent == method }!.bodyText.hasSuffix("&start=1688667769.6395"))
        }
    }

    // TradesHistory's position words, as documented (https://docs.kraken.com/api/docs/rest-api/get-trade-history.md):
    // misc "closing", "Trade closes all or part of a position"; posstatus, "Position status (open/closed) Only present
    // if trade opened a position", so either word states the trade opened one. The recorded spot trades carry neither.
    static func effects(trades edit: (String) -> String) async throws -> [ExchangeClientPositionEffect?] {
        let trades = edit(String(decoding: Recording.body("Kraken/private-trades-history.json"), as: UTF8.self))
        let session = ReplaySession(route: Kraken.route(["TradesHistory": .ok(Data(trades.utf8))]))
        return try await Kraken.client(session).ledgerItems(account: "", since: nil).map { item in
            guard case .fill(_, _, _, _, _, _, _, _, _, let effect) = item else { return nil }
            return effect
        }
    }

    @Test func aSpotTradeStatesNoPositionEffect() async throws {
        #expect(try await Self.effects { $0 } == [nil, nil])
    }

    @Test func aTradeMarkedClosingClosesAndATradeWithAPositionStatusOpened() async throws {
        // The later trade (THVRQM…, 1688667796.8802) closes; the earlier (TCWJEG…) opened a position, still open.
        let effects = try await Self.effects { text in
            text.replacingOccurrences(of: #""misc": "",\#n        "trade_id": 40274859"#, with: #""misc": "closing",\#n        "trade_id": 40274859"#)
                .replacingOccurrences(of: #""trade_id": 39482674,"#, with: #""trade_id": 39482674, "posstatus": "open","#)
        }
        #expect(effects == [.open, .close])
    }

    @Test func aTradeWhosePositionHasSinceClosedStillOpenedIt() async throws {
        let effects = try await Self.effects { $0.replacingOccurrences(of: #""trade_id": 39482674,"#, with: #""trade_id": 39482674, "posstatus": "closed","#) }
        #expect(effects == [.open, nil])
    }

    @Test func leverageTransferAndKeyFactsAreNotOfferedByKrakenSpot() async throws {
        let client = Kraken.client(ReplaySession(route: Kraken.route()))
        await #expect(throws: ExchangeClientError.notOffered(member: "setLeverage")) { try await client.setLeverage(2, market: Kraken.xbtusd, isolated: true, account: "") }
        await #expect(throws: ExchangeClientError.notOffered(member: "transfer")) { try await client.transfer(try Amount(whole: 1, of: Kraken.usd), from: "a", to: "b") }
        await #expect(throws: ExchangeClientError.notOffered(member: "keyFacts")) { try await client.keyFacts() }
        #expect(!client.hasTestMarket)
    }

    @Test func theBudgetCountsTheClientsOwnRequestsAgainstKrakensCounter() async throws {
        let session = ReplaySession(route: Kraken.route())
        let client = Kraken.client(session)
        _ = try await client.orderBook(market: Kraken.xbtusd)
        let budget = try await client.requestBudget()
        #expect(budget.limit == 15)
        #expect(budget.remaining == 15 - session.requests.count)
    }

    @Test func theMaintenanceIsTheStatusPagesWindowsAndTheNoticesThePairsNotOnline() async throws {
        let session = ReplaySession(route: Kraken.route())
        let client = Kraken.client(session)
        let windows = try await client.maintenanceWindows()
        let raw = (Recording.json("Kraken/maintenances-upcoming.json") as! [String: Any])["scheduled_maintenances"] as! [Any]
        #expect(windows.count == raw.count)
        // the recorded page: the VANRY withdrawal halt (to 10 December) and the Banking Circle funding maintenance
        #expect(windows.map(\.subject) == [.transfers, .transfers])
        #expect(windows[0].text == "VANRY withdrawals on Ethereum blockchain halted.")
        #expect(windows[0].interval.end == (try iso("2026-12-10T15:05:00.000Z")))
        #expect(try await client.notices().isEmpty) // the three recorded pairs are online
    }

    @Test func aWindowIsClassifiedByItsNameAndComponentsAndAnythingUnrecognisedIsOther() async throws {
        // constructed in the Statuspage shape of the recording; only the words differ
        func page(_ name: String, _ components: [String]) -> String {
            let parts = components.map { "{\"name\":\"\($0)\"}" }.joined(separator: ",")
            return "{\"name\":\"\(name)\",\"scheduled_for\":\"2026-10-12T18:00:00.000Z\",\"scheduled_until\":\"2026-10-12T19:00:00.000Z\",\"components\":[\(parts)],\"incident_updates\":[]}"
        }
        let body = "{\"scheduled_maintenances\":[" + [
            page("Scheduled maintenance", ["Spot Trading"]),
            page("Deposits paused", []),
            page("Funding and trading", ["Payment Methods - SEPA", "Trading"]),
            page("Website update", ["Support Site"]),
        ].joined(separator: ",") + "]}"
        let session = ReplaySession(route: Kraken.route(["upcoming.json": .ok(Data(body.utf8))]))
        let windows = try await Kraken.client(session).maintenanceWindows()
        #expect(windows.map(\.subject) == [.trading, .transfers, .trading, .other])
    }

    @Test func anOrderIdAndACursorRoundTripThroughJSON() throws {
        let id = try KrakenOrderId(validating: "OUF4EM-FRGI2-MQMWZD")
        #expect(try id.toJSON().fromJSON() == id)
        let cursor = KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667796.8802"))
        #expect(try cursor.toJSON().fromJSON() == cursor)
    }

    // The ledger cursor names the item (the owner's ruling of 2026-10-08, road A): the instant and the ids read at it.
    @Test func aCursorStoredBeforeItNamedItemsDecodesAsNamingNoneAndTheNewFormRoundTrips() throws {
        let old: KrakenLedgerCursor = try #""1688667769.6396""#.fromJSON()
        #expect(old == KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667769.6396")))
        #expect(old.read.isEmpty)
        let named = KrakenLedgerCursor(seconds: try WireDecimal(parsing: "1688667769.6396"), read: [try KrakenLedgerId(validating: "TCWJEG-FL4SZ-3FKGH6")])
        let json = try named.toJSON()
        #expect(json.hasPrefix("{"))
        #expect(try json.fromJSON() == named)
        #expect(Set([old, named, try json.fromJSON()]).count == 2)
        #expect(try KrakenLedgerCursor.stub().toJSON().fromJSON() == KrakenLedgerCursor.stub())
        #expect(try KrakenLedgerId.stub().toJSON().fromJSON() == KrakenLedgerId.stub())
        #expect(throws: (any Error).self) { let _: KrakenLedgerId = try #""not an id""#.fromJSON() }
        #expect(throws: ExchangeClientError.self) { _ = try KrakenLedgerId(validating: "") }
    }

    // The recorded TradesHistory with its later trade moved to the earlier trade's instant: two items at one instant.
    static let sameInstant = String(decoding: Recording.body("Kraken/private-trades-history.json"), as: UTF8.self)
        .replacingOccurrences(of: "1688667796.8802", with: "1688667769.6396")

    static func read(_ trades: String, since: KrakenLedgerCursor?) async throws -> [KrakenLedgerCursor] {
        let session = ReplaySession(route: Kraken.route(["TradesHistory": .ok(Data(trades.utf8))]))
        let items = try await Kraken.client(session).ledgerItems(account: "", since: since)
        var cursors: [KrakenLedgerCursor] = []
        for item in items {
            guard case .fill(_, _, _, _, _, _, _, _, let cursor, _) = item else { continue }
            cursors.append(cursor)
        }
        return cursors
    }

    @Test func twoItemsAtOneInstantAreHandedUpOnceEachAcrossTwoReads() async throws {
        let first = try KrakenLedgerId(validating: "TCWJEG-FL4SZ-3FKGH6")
        let second = try KrakenLedgerId(validating: "THVRQM-33VKH-UCI7BS")
        let instant = try WireDecimal(parsing: "1688667769.6396")
        let whole = try await Self.read(Self.sameInstant, since: nil)
        #expect(whole == [KrakenLedgerCursor(seconds: instant, read: [first]), KrakenLedgerCursor(seconds: instant, read: [first, second])])
        // Resumed from the first item's cursor: the second, at the same instant, is handed up and the first is not.
        #expect(try await Self.read(Self.sameInstant, since: whole[0]) == [whole[1]])
        // And from the second's: nothing, though the instant is read again.
        #expect(try await Self.read(Self.sameInstant, since: whole[1]).isEmpty)
        // The old, bare cursor reads as after the instant: neither item at it is named, so both come back.
        let old: KrakenLedgerCursor = try #""1688667769.6396""#.fromJSON()
        #expect(try await Self.read(Self.sameInstant, since: old) == whole)
    }

    @Test func anItemThatAppearsAtTheCursorsInstantAfterTheReadIsHandedUpAndTheNamedIsNot() async throws {
        // The first read sees one trade only; the second sees both at the one instant.
        var one = try #require(JSONSerialization.jsonObject(with: Data(Self.sameInstant.utf8)) as? [String: Any])
        var result = try #require(one["result"] as? [String: Any])
        var trades = try #require(result["trades"] as? [String: Any])
        trades["THVRQM-33VKH-UCI7BS"] = nil
        result["trades"] = trades
        one["result"] = result
        let alone = String(decoding: try JSONSerialization.data(withJSONObject: one), as: UTF8.self)
        let cursor = try #require(try await Self.read(alone, since: nil).last)
        #expect(cursor.read == [try KrakenLedgerId(validating: "TCWJEG-FL4SZ-3FKGH6")])
        let later = try await Self.read(Self.sameInstant, since: cursor)
        #expect(later.map(\.read) == [[try KrakenLedgerId(validating: "TCWJEG-FL4SZ-3FKGH6"), try KrakenLedgerId(validating: "THVRQM-33VKH-UCI7BS")]])
    }
}

// The client gaps of the identity PR (fosline's layer B ledger § 6): the client order id, and the key's facts.
@Suite("Kraken exchange client: the client gaps")
struct KrakenClientGapsTests {
    static let token: UInt128 = 0x6d1b_345e_2821_40e2_ad83_4ecb_18a0_6876

    // Kraken's AddOrder takes cl_ord_id as a long UUID, a short UUID (32 hex digits) or free text of up to 18
    // characters (docs.kraken.com, Add Order); the client writes the 128 bits as the short UUID.
    @Test func theClientOrderIdIsSentAsClOrdIdInTheShortUUIDForm() async throws {
        let queried = String(decoding: Recording.body("Kraken/private-query-orders.json"), as: UTF8.self)
            .replacingOccurrences(of: "OBCMZD-JIEE7-77TH3F", with: "OUF4EM-FRGI2-MQMWZD")
        let session = ReplaySession(route: Kraken.route(["QueryOrders": .ok(Data(queried.utf8))]))
        _ = try await Kraken.client(session).placeOrder(market: Kraken.xbtusd, side: .buy, size: try WireDecimal(parsing: "1.25").amount(of: Kraken.xbt),
                                                        limit: Kraken.price("27600"), immediateOrCancel: true, reduceOnly: false,
                                                        clientOrderId: Self.token, account: "")
        let added = try #require(session.requests.first { $0.url!.lastPathComponent == "AddOrder" })
        #expect(added.bodyText == "nonce=1791272956000&ordertype=limit&type=buy&volume=1.25&pair=XBTUSD&price=27600&timeinforce=IOC&cl_ord_id=6d1b345e282140e2ad834ecb18a06876")
    }

    // The documented Get Open Orders example states userref and no cl_ord_id: both orders hand up none.
    @Test func theRecordedOpenOrdersStateNoClientOrderId() async throws {
        let open = try await Kraken.client(ReplaySession(route: Kraken.route())).openOrders(account: "")
        #expect(open.count == 2)
        #expect(open.allSatisfy { $0.clientOrderId == nil })
    }

    // Constructed on the documented example: Get Open Orders documents cl_ord_id on each order ("Optional
    // alphanumeric, client identifier associated with the order"); a long UUID reads back, free text does not.
    @Test func anOpenOrdersClOrdIdIsHandedBackAsTheClientOrderId() async throws {
        let recorded = String(decoding: Recording.body("Kraken/private-open-orders.json"), as: UTF8.self)
            .replacingOccurrences(of: #""userref": 0,"#, with: #""userref": 0, "cl_ord_id": "6d1b345e-2821-40e2-ad83-4ecb18a06876","#)
            .replacingOccurrences(of: #""userref": 45326,"#, with: #""userref": 45326, "cl_ord_id": "arb-20240509-00010","#)
        let session = ReplaySession(route: Kraken.route(["OpenOrders": .ok(Data(recorded.utf8))]))
        let open = try await Kraken.client(session).openOrders(account: "")
        #expect(open.first { $0.id == (try! KrakenOrderId(validating: "OQCLML-BW3P3-BUCMWZ")) }?.clientOrderId == Self.token)
        #expect(open.first { $0.id == (try! KrakenOrderId(validating: "OB5VMB-B4U2U-DK2WRW")) }.map { $0.clientOrderId == nil } == true)
    }
}
