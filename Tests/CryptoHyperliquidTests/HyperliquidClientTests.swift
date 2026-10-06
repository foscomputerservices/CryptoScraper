// HyperliquidClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
@testable import CryptoHyperliquid
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// § 8.6 for Hyperliquid's exchange client: every member against recorded responses (the public reads and the owner's
// test-market account read-only on 2026-10-06, its addresses replaced by placeholders; the exchange endpoint's answers
// documentation-derived), every number decoded exactly, the errors typed, the ids and cursors round-tripping.

enum Hyperliquid {
    static let master = "0x0000000000000000000000000000000000000001"
    static let sub = "0x0000000000000000000000000000000000000002"
    static let btc = try! HyperliquidMarketName(validating: "BTC")
    static let eth = try! HyperliquidMarketName(validating: "ETH")
    static let btcAsset = try! Asset(symbol: "BTC", unitExponent: 5)
    static let recordedAt = Date(timeIntervalSince1970: 1_791_272_970)

    // /info answered from the recordings by the request's type; /exchange by `exchange`.
    static func route(exchange: String = "exchange-default-ok.json") -> @Sendable (URLRequest, Int) -> Reply {
        { request, _ in
            if request.url!.lastPathComponent == "exchange" {
                return .ok(Recording.body("Hyperliquid/\(exchange)"))
            }
            let body = request.jsonBody
            let file: String = switch body["type"] as? String {
            case "meta": "meta.json"
            case "metaAndAssetCtxs": "meta-and-asset-ctxs.json"
            case "l2Book": "l2book-btc.json"
            case "userRole": "user-role-agent.json"
            case "subAccounts": "sub-accounts.json"
            case "clearinghouseState": (body["user"] as? String) == master ? "clearinghouse-master.json" : "clearinghouse-sub.json"
            case "openOrders": "open-orders-sub.json"
            case "userFillsByTime": "fills-sub.json"
            case "userFunding": "funding-sub.json"
            case "userNonFundingLedgerUpdates": "ledger-sub.json"
            case "extraAgents": "extra-agents.json"
            case "userRateLimit": "user-rate-limit.json"
            case "userAbstraction": "user-abstraction.json"
            default: "unknown"
            }
            return .ok(Recording.body("Hyperliquid/\(file)"))
        }
    }

    static func client(_ session: ReplaySession, now: Date = recordedAt) -> HyperliquidClient {
        HyperliquidClient(credential: .agentKey(VectorFile.loaded.key), endpoint: .testMarket, session: session, now: { now })
    }

    static func price(_ text: String, of base: Asset = btcAsset) -> Price {
        try! WireDecimal(parsing: text).price(of: .usdc, per: base)
    }
}

@Suite("Hyperliquid exchange client")
struct HyperliquidClientTests {
    // MARK: Markets and books

    @Test func theMarketsAreThePerpetualsListedWithTheirLotsAndLeverage() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let markets = try await Hyperliquid.client(session).markets()
        let raw = (Recording.json("Hyperliquid/meta.json") as! [String: Any])["universe"] as! [[String: Any]]
        #expect(markets.count == raw.filter { ($0["isDelisted"] as? Bool) != true }.count)
        let btc = try #require(markets.first { $0.name == Hyperliquid.btc })
        #expect(btc.base == Hyperliquid.btcAsset)
        #expect(btc.quote == .usdc)
        #expect(btc.lotSize == Amount(baseUnits: 1, asset: Hyperliquid.btcAsset))
        #expect(btc.minimumOrder == Amount(whole: 10, of: .usdc))
        #expect(btc.maxLeverage == 40)
        #expect(btc.isPerpetual)
    }

    @Test func theBookIsTheExchangesBestBidAndAskMidAndDayVolumeExactly() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let book = try await Hyperliquid.client(session).orderBook(market: Hyperliquid.btc)
        // l2Book: bid "85836.0", ask "85838.0", time 1791272943883; BTC's context: midPx "85831.0", dayNtlVlm
        // "1994433.2905599999", the day's notional in USDC, cut toward zero at USDC's six digits
        #expect(book.bestBid == Hyperliquid.price("85836"))
        #expect(book.bestAsk == Hyperliquid.price("85838"))
        #expect(book.mid == Hyperliquid.price("85831"))
        #expect(book.volume == Amount(baseUnits: 1_994_433_290_559, asset: .usdc))
        #expect(book.readAt == Date(wireMilliseconds: 1_791_272_943_883))
    }

    // MARK: Orders

    @Test func aFilledOrderIsTheExchangesUnitsPriceAndId() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let size = Amount(baseUnits: 2_000, asset: Hyperliquid.btcAsset) // 0.02 BTC, the documented fill's size
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: size, limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x"
        )
        #expect(result == .filled(units: size, at: Hyperliquid.price("1891.4"), id: HyperliquidOrderId(77_747_314), time: Hyperliquid.recordedAt))
    }

    @Test func aSmallerFillIsAPartialFill() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 3_000, asset: Hyperliquid.btcAsset), limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x"
        )
        guard case .partlyFilled(let units, _, _, _) = result else {
            Issue.record("Not a partial fill: \(result)")
            return
        }
        #expect(units == Amount(baseUnits: 2_000, asset: Hyperliquid.btcAsset))
    }

    @Test func theOrderIsSignedForTheSubAccountWithTheActionThePOCSigns() async throws {
        let vector = try #require(VectorFile.loaded.vectors.first { $0.name.hasPrefix("order: limit IOC buy BTC") && !$0.isMainnet })
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let client = Hyperliquid.client(session, now: Date(wireMilliseconds: Int64(vector.nonce)))
        _ = try await client.placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 123, asset: Hyperliquid.btcAsset), limit: Hyperliquid.price("64300.5"),
            immediateOrCancel: true, reduceOnly: false, account: try #require(vector.vaultAddress)
        )
        let sent = try #require(session.requests.last { $0.url!.lastPathComponent == "exchange" })
        #expect(sent.bodyText.hasPrefix("{\"action\":\(vector.actionJSON),\"nonce\":\(vector.nonce),"))
        #expect(sent.bodyText.contains("\"r\":\"\(vector.r)\",\"s\":\"\(vector.s)\",\"v\":\(vector.v)"))
        #expect(sent.bodyText.hasSuffix("\"vaultAddress\":\"\(vector.vaultAddress!)\"}"))
    }

    @Test func theCancelAndTheLeverageCarryThePOCsSignatures() async throws {
        let vectors = VectorFile.loaded.vectors.filter { !$0.isMainnet }
        let cancel = try #require(vectors.first { $0.name.hasPrefix("cancel") })
        let leverage = try #require(vectors.first { $0.name.hasPrefix("leverage") })

        let cancelling = ReplaySession(route: Hyperliquid.route(exchange: "exchange-cancel-success.json"))
        try await Hyperliquid.client(cancelling, now: Date(wireMilliseconds: Int64(cancel.nonce)))
            .cancelOrder(HyperliquidOrderId(77_738_310), market: Hyperliquid.btc, account: cancel.vaultAddress!)
        #expect(cancelling.requests.last!.bodyText.contains("\"r\":\"\(cancel.r)\",\"s\":\"\(cancel.s)\""))

        let levering = ReplaySession(route: Hyperliquid.route())
        try await Hyperliquid.client(levering, now: Date(wireMilliseconds: Int64(leverage.nonce)))
            .setLeverage(5, market: Hyperliquid.btc, isolated: true, account: leverage.vaultAddress!)
        #expect(levering.requests.last!.bodyText.contains("\"r\":\"\(leverage.r)\",\"s\":\"\(leverage.s)\""))
    }

    @Test func aRestingOrderIsHandedUpAsRestingWithItsId() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-resting.json"))
        let limit = Hyperliquid.price("60000")
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 100, asset: Hyperliquid.btcAsset), limit: limit,
            immediateOrCancel: false, reduceOnly: false, account: Hyperliquid.master
        )
        #expect(result == .resting(id: HyperliquidOrderId(77_738_308), time: Hyperliquid.recordedAt))
        // The main wallet's own account is signed for with no vault.
        #expect(!session.requests.last!.bodyText.contains("vaultAddress"))
    }

    @Test func aRefusedOrderIsTheExchangesWords() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-error.json"))
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 1, asset: Hyperliquid.btcAsset), limit: Hyperliquid.price("60000"),
            immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x"
        )
        #expect(result == .refused(code: "order", text: "Order must have minimum value of $10."))
    }

    @Test func anIOCThatMatchedNothingWasCancelledBeforeAccepted() async throws {
        let body = Data(#"{"status":"ok","response":{"type":"order","data":{"statuses":[{"error":"Order could not immediately match against any resting orders. asset=3"}]}}}"#.utf8)
        let session = ReplaySession { request, index in
            request.url!.lastPathComponent == "exchange" ? .ok(body) : Hyperliquid.route()(request, index)
        }
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 1_000, asset: Hyperliquid.btcAsset), limit: Hyperliquid.price("60000"),
            immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x"
        )
        #expect(result == .cancelledBeforeAccepted)
    }

    @Test func aCancelTheExchangeRefusesThrowsItsWords() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-cancel-error.json"))
        await #expect(throws: ExchangeClientError.refused(code: nil, text: "Order was never placed, already canceled, or filled.")) {
            try await Hyperliquid.client(session).cancelOrder(HyperliquidOrderId(1), market: Hyperliquid.btc, account: "four-hour-2x")
        }
    }

    @Test func anErrStatusNamingTheAgentIsUnauthorizedWithHyperliquidsWords() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-err.json"))
        #expect(await sharedError { try await Hyperliquid.client(session).setLeverage(2, market: Hyperliquid.btc, isolated: true, account: "four-hour-2x") }
            == .unauthorized(text: "User or API Wallet 0x00000000000000000000000000000000000000a1 does not exist."))
    }

    @Test func anErrStatusOtherwiseIsRefusedWithHyperliquidsWords() async throws {
        let body = Data(#"{"status":"err","response":"Cannot modify leverage with open orders."}"#.utf8)
        let session = ReplaySession { request, index in
            request.url!.lastPathComponent == "exchange" ? .ok(body) : Hyperliquid.route()(request, index)
        }
        #expect(await sharedError { try await Hyperliquid.client(session).setLeverage(2, market: Hyperliquid.btc, isolated: true, account: "four-hour-2x") }
            == .refused(code: nil, text: "Cannot modify leverage with open orders."))
    }

    @Test func aStatus500IsRefusedWithItsStatusAsTheCodeAndItsBodyAsTheText() async throws {
        let session = ReplaySession { _, _ in Reply(status: 500, body: Data("null".utf8), headers: [:]) }
        #expect(await sharedError { try await Hyperliquid.client(session).markets() } == .refused(code: "500", text: "null"))
    }

    @Test func aStatus401IsUnauthorized() async throws {
        let session = ReplaySession { _, _ in Reply(status: 401, body: Data("Unauthorized".utf8), headers: [:]) }
        #expect(await sharedError { try await Hyperliquid.client(session).markets() } == .unauthorized(text: "Unauthorized"))
    }

    @Test func a429WithRetryAfterIsRateLimitedWithItsWait() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "4"]) }
        #expect(await sharedError { try await Hyperliquid.client(session).markets() } == .rateLimited(retryAfter: .seconds(4)))
    }

    @Test func aMalformedBodyIsMalformedResponseNeverAValue() async throws {
        let session = ReplaySession { _, _ in .ok(Data(#"{"universe":[{"name":"BTC","szDecimals":"five"}]}"#.utf8)) }
        #expect(await sharedError { try await Hyperliquid.client(session).markets() }?.meaning == "malformedResponse")
    }

    @Test func noAnswerIsUnreachableWithTheTransportsText() async throws {
        let session = ReplaySession { _, _ in .failing(URLError(.timedOut)) }
        #expect(await sharedError { try await Hyperliquid.client(session).markets() } == .unreachable(text: URLError(.timedOut).localizedDescription))
    }

    @Test func aNumberFinerThanTheAssetIsMalformedResponseNeverRounded() async throws {
        let session = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "clearinghouseState"
                ? .ok(Data(#"{"marginSummary":{"accountValue":"1.0000001"},"withdrawable":"0","assetPositions":[],"time":1}"#.utf8))
                : Hyperliquid.route()(request, index)
        }
        #expect(await sharedError { try await Hyperliquid.client(session).accountState(account: Hyperliquid.master) }?.meaning == "malformedResponse")
    }

    @Test func aClientWithoutACredentialReadsTheMarketsAndSignsNothing() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let client = HyperliquidClient(credential: nil, endpoint: .testMarket, session: session)
        #expect(try await client.markets().isEmpty == false)
        await #expect(throws: ExchangeClientError.unauthorized(text: "The client was made without a credential")) {
            try await client.keyFacts()
        }
    }

    // MARK: The account

    @Test func theOpenOrdersOfAnAccountAreItsSubAccounts() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        #expect(try await Hyperliquid.client(session).openOrders(account: "four-hour-2x").isEmpty)
        let asked = session.requests.first { $0.jsonBody["type"] as? String == "openOrders" }
        #expect(asked?.jsonBody["user"] as? String == Hyperliquid.sub)
    }

    @Test func theAccountStateIsTheExchangesMoneyPositionsAndModeExactly() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let state = try await Hyperliquid.client(session).accountState(account: "four-hour-2x")
        // clearinghouse-sub: accountValue "69.526412", withdrawable "20.816414", four isolated longs, time 1791272972793
        #expect(state.balance == Amount(baseUnits: 69_526_412, asset: .usdc))
        #expect(state.withdrawable == Amount(baseUnits: 20_816_414, asset: .usdc))
        #expect(state.readAt == Date(wireMilliseconds: 1_791_272_972_793))
        #expect(state.positions.map(\.market) == ["ETH", "BNB", "NEO", "RUNE"].map { try! HyperliquidMarketName(validating: $0) })
        let eth = try #require(state.positions.first)
        let ethAsset = try Asset(symbol: "ETH", unitExponent: 4)
        #expect(eth.side == .buy)
        #expect(eth.units == Amount(baseUnits: 88, asset: ethAsset))
        #expect(eth.entryPrice == Hyperliquid.price("2700.1", of: ethAsset))
        #expect(eth.liquidationPrice == Hyperliquid.price("1348.1851808905", of: ethAsset))
        #expect(state.mode == ExchangeClientAccountMode(name: "disabled", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: ["unifiedAccount", "portfolioMargin"]))
    }

    @Test func theLedgerIsTheFillsTheFundingAndTheMovesInTimeOrderEachWithItsCursor() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        #expect(items.count == 36 + 500 + 4)
        let cursors = items.map { item -> Int64 in
            switch item {
            case .fill(_, _, _, _, _, _, _, _, let cursor), .funding(_, _, _, _, let cursor),
                 .deposit(_, _, let cursor), .withdrawal(_, _, let cursor), .internalMove(_, _, _, _, let cursor): cursor.milliseconds
            }
        }
        #expect(cursors == cursors.sorted())

        // The first fill: RUNE, px "0.64592", sz "43.6", side B, fee "0.012672", oid 60807847573.
        let rune = try Asset(symbol: "RUNE", unitExponent: 1)
        let fill = try #require(items.first { if case .fill = $0 { true } else { false } })
        #expect(fill == .fill(market: try HyperliquidMarketName(validating: "RUNE"), side: .buy, units: Amount(baseUnits: 436, asset: rune),
                              price: Hyperliquid.price("0.64592", of: rune), fee: Amount(baseUnits: 12_672, asset: .usdc),
                              order: HyperliquidOrderId(60_807_847_573), closedBy: nil, time: Date(wireMilliseconds: 1_790_136_043_481),
                              cursor: HyperliquidLedgerCursor(milliseconds: 1_790_136_043_481)))
        // A transfer between the main account and the sub-account is a move between their addresses.
        #expect(items.contains { if case .internalMove(let amount, _, _, _, _) = $0 { amount == Amount(whole: 20, of: .usdc) } else { false } })
    }

    @Test func aFundingRateFinerThanNineDigitsIsCutTowardZeroAtNine() throws {
        #expect(try HyperliquidClient.rate(WireDecimal(parsing: "-0.0000290747")) == (try WireDecimal(parsing: "-0.000029074").fraction()))
        #expect(try HyperliquidClient.rate(WireDecimal(parsing: "0.0000125")) == (try WireDecimal(parsing: "0.0000125").fraction()))
    }

    @Test func aTransferIntoASubAccountIsADepositOfMicroDollars() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        try await Hyperliquid.client(session).transfer(Amount(baseUnits: 500_250_000, asset: .usdc), from: Hyperliquid.master, to: "four-hour-2x")
        let action = try #require(session.requests.last!.jsonBody["action"] as? [String: Any])
        #expect(action["type"] as? String == "subAccountTransfer")
        #expect(action["subAccountUser"] as? String == Hyperliquid.sub)
        #expect(action["isDeposit"] as? Bool == true)
        #expect((action["usd"] as? NSNumber)?.int64Value == 500_250_000)
        await #expect(throws: ExchangeClientError.refused(code: nil, text: "Hyperliquid moves funds only between the main account and one of its sub-accounts")) {
            try await Hyperliquid.client(session).transfer(Amount(whole: 1, of: .usdc), from: "four-hour-2x", to: "four-hour-1x")
        }
    }

    @Test func theKeyFactsAreTheApprovalHyperliquidStates() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let facts = try await Hyperliquid.client(session).keyFacts()
        // The throwaway key is not the recorded agent: it is not approved.
        #expect(facts == ExchangeClientKeyFacts(canTrade: false, canTransfer: false, canWithdraw: false, approvedBy: nil, validUntil: nil))
    }

    @Test func theRequestBudgetIsTheAddressesCapAndUse() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        #expect(try await Hyperliquid.client(session).requestBudget() == ExchangeClientRequestBudget(limit: 115_089, remaining: 115_013, resetsAt: .distantFuture))
    }

    @Test func theNoticesAreTheDelistedPerpetualsAndNoWindowIsAnnounced() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let client = Hyperliquid.client(session)
        let notices = try await client.notices()
        #expect(notices.contains { $0.market == (try! HyperliquidMarketName(validating: "MATIC")) && $0.kind == .delisting })
        #expect(try await client.maintenanceWindows().isEmpty)
        #expect(client.hasTestMarket)
    }

    @Test func anOrderIdAndACursorRoundTripThroughJSON() throws {
        #expect(try HyperliquidOrderId(77_738_308).toJSON().fromJSON() == HyperliquidOrderId(77_738_308))
        #expect(try HyperliquidLedgerCursor(milliseconds: 1_790_136_043_481).toJSON().fromJSON() == HyperliquidLedgerCursor(milliseconds: 1_790_136_043_481))
    }
}
