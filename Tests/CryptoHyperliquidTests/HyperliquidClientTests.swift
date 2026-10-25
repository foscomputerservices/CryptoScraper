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
    // Hyperliquid's declared holdings (step 4b of the identity PR), declared in the shared registry before any amount
    // is made in them, whichever test runs first
    static let btcAsset: AssetInstance = declared(HyperliquidHolding.btc)
    static let usdc: AssetInstance = declared(HyperliquidHolding.usdc)
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
            case "spotClearinghouseState": "spot-master.json"
            case "extraAgents": "extra-agents.json"
            case "userRateLimit": "user-rate-limit.json"
            case "userAbstraction": "user-abstraction.json"
            case "userFees": "user-fees.json"
            default: "unknown"
            }
            return .ok(windowed(Recording.body("Hyperliquid/\(file)"), request))
        }
    }

    // A recorded windowed read answered as the exchange answers it: the items at or after the request's `startTime`
    // (inclusive, per Hyperliquid's documentation), so a client walking pages from the last item's time gets that
    // item again and no more. A recording that is no list, or a request without a start, is served whole.
    static func windowed(_ body: Data, _ request: URLRequest) -> Data {
        guard let start = request.jsonBody["startTime"] as? Int64,
              let items = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]] else { return body }
        let kept = items.filter { (($0["time"] as? Int64) ?? 0) >= start }
        return try! JSONSerialization.data(withJSONObject: kept)
    }

    static func client(_ session: ReplaySession, now: Date = recordedAt) -> HyperliquidClient {
        HyperliquidClient(credential: .agentKey(VectorFile.loaded.key), endpoint: .testMarket, session: session, now: { now })
    }

    static func declared(_ holding: HyperliquidHolding) -> AssetInstance {
        do {
            try HyperliquidExchangeChain.declare(in: .shared)
        } catch {
            preconditionFailure("Hyperliquid's declarations conflict with the shared registry: \(error)")
        }
        return AssetInstance(holding)
    }

    static func price(_ text: String, of base: AssetInstance = btcAsset) -> Price {
        try! WireDecimal(parsing: text).price(of: usdc, per: base)
    }
}

@Suite("Hyperliquid exchange client")
struct HyperliquidClientTests {
    // MARK: Markets and books

    // Carried in step 4b of the identity PR: the market's base is Hyperliquid's declared holding, no longer an asset made
    // from the coin's name and size decimals; its quote and its $10 minimum are in Hyperliquid's USDC holding.
    @Test func theMarketsAreThePerpetualsListedWithTheirLotsAndLeverage() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let markets = try await Hyperliquid.client(session).markets()
        let raw = (Recording.json("Hyperliquid/meta.json") as! [String: Any])["universe"] as! [[String: Any]]
        #expect(markets.count == raw.filter { ($0["isDelisted"] as? Bool) != true }.count)
        let btc = try #require(markets.first { $0.name == Hyperliquid.btc })
        #expect(btc.base == Hyperliquid.btcAsset)
        #expect(btc.quote == Hyperliquid.usdc)
        #expect(btc.lotSize == Amount(baseUnits: 1, of: Hyperliquid.btcAsset))
        #expect(btc.minimumOrder == (try Amount(whole: 10, of: Hyperliquid.usdc)))
        #expect(btc.maxLeverage == 40)
        #expect(btc.isPerpetual)
    }

    // Added 2026-10-09: the recorded testnet `meta` lists DOGE, SAND, NEO, RUNE and ALGO; each market's base is its
    // declared holding, and its lot one base unit of it.
    @Test func theRecordedMarketsCarryDOGESANDNEORUNEAndALGOsDeclaredBases() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let markets = try await Hyperliquid.client(session).markets()
        for holding in [HyperliquidHolding.doge, .sand, .neo, .rune, .algo] {
            let base = Hyperliquid.declared(holding)
            let market = try #require(markets.first { $0.name.text == holding.wireName })
            #expect(market.base == base)
            #expect(market.lotSize == Amount(baseUnits: 1, of: base))
            #expect(market.quote == Hyperliquid.usdc)
        }
    }

    @Test func theBookIsTheExchangesBestBidAndAskMidAndDayVolumeExactly() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let book = try await Hyperliquid.client(session).orderBook(market: Hyperliquid.btc)
        // l2Book: bid "85836.0", ask "85838.0", time 1791272943883; BTC's context: midPx "85831.0", dayBaseVlm
        // "23.18704", dayNtlVlm "1994433.2905599999", the day's turnover in USDC, cut toward zero at USDC's eight digits
        #expect(book.bestBid == Hyperliquid.price("85836"))
        #expect(book.bestAsk == Hyperliquid.price("85838"))
        #expect(book.mid == Hyperliquid.price("85831"))
        #expect(book.baseVolume == Amount(baseUnits: 2_318_704, of: Hyperliquid.btcAsset))
        #expect(book.quoteVolume == Amount(baseUnits: 199_443_329_055_999, of: Hyperliquid.usdc))
        #expect(book.readAt == Date(wireMilliseconds: 1_791_272_943_883))
    }

    // MARK: Orders

    @Test func aFilledOrderIsTheExchangesUnitsPriceAndId() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let size = Amount(baseUnits: 2_000, of: Hyperliquid.btcAsset) // 0.02 BTC, the documented fill's size
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: size, limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "four-hour-2x"
        )
        #expect(result == .filled(units: size, at: Hyperliquid.price("1891.4"), id: HyperliquidOrderId(77_747_314), time: Hyperliquid.recordedAt))
    }

    @Test func aSmallerFillIsAPartialFill() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 3_000, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "four-hour-2x"
        )
        guard case .partlyFilled(let units, _, _, _) = result else {
            Issue.record("Not a partial fill: \(result)")
            return
        }
        #expect(units == Amount(baseUnits: 2_000, of: Hyperliquid.btcAsset))
    }

    @Test func theOrderIsSignedForTheSubAccountWithTheActionThePOCSigns() async throws {
        let vector = try #require(VectorFile.loaded.vectors.first { $0.name.hasPrefix("order: limit IOC buy BTC") && !$0.isMainnet })
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        let client = Hyperliquid.client(session, now: Date(wireMilliseconds: Int64(vector.nonce)))
        _ = try await client.placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 123, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("64300.5"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: try #require(vector.vaultAddress)
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
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 100, of: Hyperliquid.btcAsset), limit: limit,
            immediateOrCancel: false, reduceOnly: false, clientOrderId: nil, account: Hyperliquid.master
        )
        #expect(result == .resting(id: HyperliquidOrderId(77_738_308), time: Hyperliquid.recordedAt))
        // The main wallet's own account is signed for with no vault.
        #expect(!session.requests.last!.bodyText.contains("vaultAddress"))
    }

    @Test func aRefusedOrderIsTheExchangesWords() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-error.json"))
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 1, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("60000"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "four-hour-2x"
        )
        #expect(result == .refused(code: "order", text: "Order must have minimum value of $10."))
    }

    @Test func anIOCThatMatchedNothingWasCancelledBeforeAccepted() async throws {
        let body = Data(#"{"status":"ok","response":{"type":"order","data":{"statuses":[{"error":"Order could not immediately match against any resting orders. asset=3"}]}}}"#.utf8)
        let session = ReplaySession { request, index in
            request.url!.lastPathComponent == "exchange" ? .ok(body) : Hyperliquid.route()(request, index)
        }
        let result = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 1_000, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("60000"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "four-hour-2x"
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
                ? .ok(Data(#"{"marginSummary":{"accountValue":"1.000000001"},"withdrawable":"0","assetPositions":[],"time":1}"#.utf8))
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

    // Carried in step 4b of the identity PR: the recorded sub-account's BNB, NEO and RUNE positions are in holdings no
    // class declares, and a money value in one is refused (HyperliquidScannerTests/aPositionInAnUndeclaredHoldingIsRefused),
    // so the state is read over the recording with its ETH position alone; ETH is Hyperliquid's declared holding. (BNB
    // has been declared since step 4c; its position is read in HyperliquidScannerTests/theRecordedBNBPositionIsReadInTheBNBHolding.)
    @Test func theAccountStateIsTheExchangesMoneyPositionsAndModeExactly() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let state = try await Hyperliquid.client(session).accountState(account: "four-hour-2x")
        // clearinghouse-sub: accountValue "69.526412", withdrawable "20.816414", its ETH long, time 1791272972793
        #expect(state.balance == Amount(baseUnits: 6_952_641_200, of: Hyperliquid.usdc))
        #expect(state.withdrawable == Amount(baseUnits: 2_081_641_400, of: Hyperliquid.usdc))
        #expect(state.readAt == Date(wireMilliseconds: 1_791_272_972_793))
        #expect(state.positions.map(\.market) == ["ETH"].map { try! HyperliquidMarketName(validating: $0) })
        let eth = try #require(state.positions.first)
        let ethAsset = AssetInstance(HyperliquidHolding.eth)
        #expect(eth.side == .buy)
        #expect(eth.units == Amount(baseUnits: 88, of: ethAsset))
        #expect(eth.entryPrice == Hyperliquid.price("2700.1", of: ethAsset))
        #expect(eth.liquidationPrice == Hyperliquid.price("1348.1851808905", of: ethAsset))
        // The recorded position's unrealizedPnl "0.000616" and marginUsed "12.134747", in USDC at eight places.
        #expect(eth.openProfit == Amount(baseUnits: 61_600, of: Hyperliquid.usdc))
        #expect(eth.heldMargin == Amount(baseUnits: 1_213_474_700, of: Hyperliquid.usdc))
        // The recorded position's leverage {"type":"isolated","value":2,…}.
        #expect(eth.marginKind == .isolated)
        #expect(state.mode == ExchangeClientAccountMode(name: "disabled", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: ["unifiedAccount", "portfolioMargin"]))
    }

    // Carried in step 4b of the identity PR: the recorded fills in ALGO, BNB, NEO and RUNE are in holdings no class
    // declares, and a money value in one is refused, so the ledger is read over the recording with its ETH fills alone;
    // the funding payments and the moves, all in USDC, are read whole. (BNB has been declared since step 4c.)
    @Test func theLedgerIsTheFillsTheFundingAndTheMovesInTimeOrderEachWithItsCursor() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        #expect(items.count == 11 + 500 + 4)
        let cursors = items.map { item -> Int64 in
            switch item {
            case .fill(_, _, _, _, _, _, _, _, _, let cursor, _, _), .funding(_, _, _, _, let cursor, _),
                 .deposit(_, _, _, let cursor, _, _), .withdrawal(_, _, _, let cursor, _, _), .internalMove(_, _, _, _, _, let cursor, _): cursor.milliseconds
            }
        }
        #expect(cursors == cursors.sorted())

        // The first ETH fill: px "2640.2", sz "0.008", side A, fee "0.009504", oid 61246678885.
        let eth = AssetInstance(HyperliquidHolding.eth)
        let fill = try #require(items.first { if case .fill = $0 { true } else { false } })
        #expect(fill == .fill(market: try HyperliquidMarketName(validating: "ETH"), side: .sell, units: Amount(baseUnits: 80, of: eth),
                              price: Hyperliquid.price("2640.2", of: eth), fee: Amount(baseUnits: 950_400, of: Hyperliquid.usdc),
                              order: HyperliquidOrderId(61_246_678_885), id: HyperliquidFillId(520_656_802_617_420), closedBy: nil, time: Date(wireMilliseconds: 1_790_568_059_898),
                              cursor: HyperliquidLedgerCursor(milliseconds: 1_790_568_059_898, place: 1), positionEffect: .close, wallet: .perpetuals))
        // A transfer between the main account and the sub-account is a move between their addresses, on the perpetuals wallet at both ends.
        #expect(items.contains { if case .internalMove(let amount, let from, let to, _, _, _, _) = $0 {
            amount == (try? Amount(whole: 20, of: Hyperliquid.usdc)) && from == ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals) && to == ExchangeClientLedgerSide(account: Hyperliquid.sub, wallet: .perpetuals)
        } else { false } })
    }

    // The owner's ruling (2026-10-07): a fill states what it did to the position. Hyperliquid states it in `dir`; its
    // table maps the four words, and any other to nil.
    @Test func theDirectionsTableMapsTheFourWordsAndNoOther() {
        #expect(HyperliquidClient.positionEffect(dir: "Open Long") == .open)
        #expect(HyperliquidClient.positionEffect(dir: "Open Short") == .open)
        #expect(HyperliquidClient.positionEffect(dir: "Close Long") == .close)
        #expect(HyperliquidClient.positionEffect(dir: "Close Short") == .close)
        #expect(HyperliquidClient.positionEffect(dir: "Long > Short") == nil)
        #expect(HyperliquidClient.positionEffect(dir: "open long") == nil)
    }

    // The recording's eleven ETH fills in time order, their `dir`: Close Long, Open Long, Close Long, Open Long,
    // Close Long, Open Short, Open Short, Close Short, Open Long, Close Long, Open Long.
    @Test func eachRecordedFillStatesItsPositionEffect() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let effects = items.compactMap { item -> ExchangeClientPositionEffect?? in
            guard case .fill(_, _, _, _, _, _, _, _, _, _, let effect, _) = item else { return nil }
            return .some(effect)
        }
        #expect(effects == [.close, .open, .close, .open, .close, .open, .open, .close, .open, .close, .open])
    }

    @Test func aFillWithAnotherWordStatesNoPositionEffect() async throws {
        let fills = String(decoding: HyperliquidScannerTests.kept("fills-sub.json", coins: ["ETH"]), as: UTF8.self)
            .replacingOccurrences(of: "Close Short", with: "Short > Long")
        let route = HyperliquidScannerTests.declaredOnlyRoute()
        let session = ReplaySession(route: { request, index in
            request.jsonBody["type"] as? String == "userFillsByTime" ? .ok(Data(fills.utf8)) : route(request, index)
        })
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let effects = items.compactMap { item -> ExchangeClientPositionEffect?? in
            guard case .fill(_, _, _, _, _, _, _, _, _, _, let effect, _) = item else { return nil }
            return .some(effect)
        }
        #expect(effects == [.close, .open, .close, .open, .close, .open, .open, nil, .open, .close, .open])
    }

    @Test func aFundingRateFinerThanNineDigitsIsCutTowardZeroAtNine() throws {
        #expect(try HyperliquidClient.rate(WireDecimal(parsing: "-0.0000290747")) == (try WireDecimal(parsing: "-0.000029074").fraction()))
        #expect(try HyperliquidClient.rate(WireDecimal(parsing: "0.0000125")) == (try WireDecimal(parsing: "0.0000125").fraction()))
    }

    // Hyperliquid moves USDC in whole millionths; the holding counts hundred-millionths. A finer amount is refused,
    // never rounded, and nothing is sent.
    @Test func aTransferFinerThanAMillionthIsRefusedAndNothingIsSent() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        await #expect(throws: ExchangeClientError.refused(code: nil, text: "Hyperliquid moves USDC in whole millionths, not 500.25000001")) {
            try await Hyperliquid.client(session).transfer(Amount(baseUnits: 50_025_000_001, of: Hyperliquid.usdc), from: Hyperliquid.master, to: "four-hour-2x")
        }
        #expect(!session.requests.contains { $0.url!.lastPathComponent == "exchange" })
    }

    // Carried in step 4b of the identity PR: the amount is in Hyperliquid's USDC holding, its hundred-millionths sent as
    // Hyperliquid's millionths (500.25 USDC).
    @Test func aTransferIntoASubAccountIsADepositOfMicroDollars() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        try await Hyperliquid.client(session).transfer(Amount(baseUnits: 50_025_000_000, of: Hyperliquid.usdc), from: Hyperliquid.master, to: "four-hour-2x")
        let action = try #require(session.requests.last!.jsonBody["action"] as? [String: Any])
        #expect(action["type"] as? String == "subAccountTransfer")
        #expect(action["subAccountUser"] as? String == Hyperliquid.sub)
        #expect(action["isDeposit"] as? Bool == true)
        #expect((action["usd"] as? NSNumber)?.int64Value == 500_250_000)
        await #expect(throws: ExchangeClientError.refused(code: nil, text: "Hyperliquid moves funds only between the main account and one of its sub-accounts")) {
            try await Hyperliquid.client(session).transfer(try Amount(whole: 1, of: Hyperliquid.usdc), from: "four-hour-2x", to: "four-hour-1x")
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
        #expect(try HyperliquidLedgerCursor(milliseconds: 1_790_136_043_481, place: 2).toJSON().fromJSON() == HyperliquidLedgerCursor(milliseconds: 1_790_136_043_481, place: 2))
    }
}

// The client gaps of the identity PR (fosline's layer B ledger § 6): the client order id, the ledger cursor's place,
// the leverage set, and the order answer's time.
@Suite("Hyperliquid exchange client: the client gaps")
struct HyperliquidClientGapsTests {
    static let token: UInt128 = 0x0123_4567_89ab_cdef_0011_2233_4455_6677

    @Test func theClientOrderIdIsSentAsTheOrdersCloidAfterItsType() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        _ = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 2_000, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: Self.token, account: "four-hour-2x"
        )
        let sent = try #require(session.requests.last { $0.url!.lastPathComponent == "exchange" })
        // The Python SDK's order wire: a, b, p, s, r, t, then c, the cloid, 16 bytes as 0x and 32 hex digits.
        #expect(sent.bodyText.contains(#""t":{"limit":{"tif":"Ioc"}},"c":"0x0123456789abcdef0011223344556677"}]"#))
    }

    @Test func noClientOrderIdSendsNoCloid() async throws {
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-filled.json"))
        _ = try await Hyperliquid.client(session).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 2_000, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("1900"),
            immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "four-hour-2x"
        )
        let sent = try #require(session.requests.last { $0.url!.lastPathComponent == "exchange" })
        #expect(!sent.bodyText.contains(#""c":"#))
    }

    // Constructed: the documented open order (info endpoint, openOrders) with a cloid, as the order status answer
    // documents one, beside the documented one with none.
    @Test func anOpenOrderHandsItsCloidBackAsTheClientOrderId() async throws {
        let body = Data(#"[{"coin":"BTC","limitPx":"29792.0","oid":91490942,"side":"A","sz":"0.001","timestamp":1681247412573,"cloid":"0x0123456789abcdef0011223344556677"},{"coin":"BTC","limitPx":"29792.0","oid":91490943,"side":"B","sz":"0.002","timestamp":1681247412573}]"#.utf8)
        let session = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "openOrders" ? .ok(body) : Hyperliquid.route()(request, index)
        }
        let open = try await Hyperliquid.client(session).openOrders(account: "four-hour-2x")
        #expect(open.map(\.clientOrderId) == [Self.token, nil])
        #expect(open.map(\.id) == [HyperliquidOrderId(91_490_942), HyperliquidOrderId(91_490_943)])
    }

    // The recording's two ETH fills in one millisecond, 1790812844835, of one order: tids 295733223166686 (0.0055)
    // and 594224716271362 (0.0034).
    @Test func twoFillsInOneMillisecondCarryTheirPlaces() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let pair = items.compactMap { item -> (Amount, HyperliquidLedgerCursor)? in
            guard case .fill(_, _, let units, _, _, _, _, _, let time, let cursor, _, _) = item, time == Date(wireMilliseconds: 1_790_812_844_835) else { return nil }
            return (units, cursor)
        }
        let eth = AssetInstance(HyperliquidHolding.eth)
        #expect(pair.map(\.0) == [Amount(baseUnits: 55, of: eth), Amount(baseUnits: 34, of: eth)])
        #expect(pair.map(\.1) == [HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 1),
                                  HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 2)])
        // No two items share a cursor.
        let cursors = items.map(Self.cursor)
        #expect(Set(cursors).count == cursors.count)
    }

    @Test func aReadResumedAfterTheFirstOfTwoFillsInOneMillisecondHandsUpTheSecond() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let after = HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 1)
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: after)
        // Asked from the cursor's millisecond, inclusive; nothing at or before the cursor's place comes back.
        let asked = session.requests.filter { $0.jsonBody["type"] as? String == "userFillsByTime" }
        #expect(asked.map { ($0.jsonBody["startTime"] as? NSNumber)?.int64Value } == [1_790_812_844_835])
        let first = try #require(items.first)
        guard case .fill(_, _, let units, _, _, _, _, _, let time, let cursor, _, _) = first else {
            Issue.record("Not a fill: \(first)")
            return
        }
        #expect(units == Amount(baseUnits: 34, of: AssetInstance(HyperliquidHolding.eth)))
        #expect(time == Date(wireMilliseconds: 1_790_812_844_835))
        #expect(cursor == HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 2))
        #expect(items.allSatisfy { Self.cursor($0).milliseconds >= 1_790_812_844_835 })
    }

    @Test func theCursorEncodesItsPlaceAndTheMillisecondAloneReadsAsPlaceZero() throws {
        let cursor = HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 2)
        #expect(String(decoding: try JSONEncoder().encode(cursor), as: UTF8.self).contains(#""place":2"#))
        #expect(try JSONDecoder().decode(HyperliquidLedgerCursor.self, from: Data("1790812844835".utf8)) == HyperliquidLedgerCursor(milliseconds: 1_790_812_844_835, place: 0))
    }

    // The main wallet's state is answered with the sub-account's recording, the one recorded with positions: ETH's
    // position is isolated at 2; BTC has none.
    @Test func aMarketWithAPositionStatesItsLeverageSetAndOneWithoutStatesNone() async throws {
        let session = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "clearinghouseState"
                ? .ok(Recording.body("Hyperliquid/clearinghouse-sub.json"))
                : Hyperliquid.route()(request, index)
        }
        let markets = try await Hyperliquid.client(session).markets()
        #expect(markets.first { $0.name == Hyperliquid.eth }?.leverageSet == 2)
        #expect(markets.first { $0.name == Hyperliquid.btc }.map { $0.leverageSet == nil } == true)
        let asked = session.requests.filter { $0.jsonBody["type"] as? String == "clearinghouseState" }
        #expect(asked.map { $0.jsonBody["user"] as? String } == [Hyperliquid.master])
    }

    @Test func aClientWithoutACredentialStatesNoLeverageSetAndAsksNoState() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let markets = try await HyperliquidClient(credential: nil, endpoint: .testMarket, session: session).markets()
        #expect(markets.allSatisfy { $0.leverageSet == nil })
        #expect(!session.requests.contains { $0.jsonBody["type"] as? String == "clearinghouseState" })
    }

    // Hyperliquid's order answer states no time: the result's time is the client's clock when the answer arrived.
    @Test func theOrderAnswersTimeIsTheClientsClock() async throws {
        let clock = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ReplaySession(route: Hyperliquid.route(exchange: "exchange-order-resting.json"))
        let result = try await Hyperliquid.client(session, now: clock).placeOrder(
            market: Hyperliquid.btc, side: .buy, size: Amount(baseUnits: 100, of: Hyperliquid.btcAsset), limit: Hyperliquid.price("60000"),
            immediateOrCancel: false, reduceOnly: false, clientOrderId: nil, account: Hyperliquid.master
        )
        #expect(result == .resting(id: HyperliquidOrderId(77_738_308), time: clock))
    }

    // MARK: A fill's id and the account's fee rates (fosline's WI-20 ask of 2026-10-24)

    // A fill's id is its trade id, which tells two fills of one transaction apart (mainnet, 2026-10-24: 2000 fills,
    // 1761 hashes); the recorded 36 fills carry 36 distinct tids. A fill without one refuses the read.
    @Test func aFillsIdIsItsTradeIdAndAFillWithoutOneIsRefused() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let ids = items.compactMap { item -> HyperliquidFillId? in if case let .fill(_, _, _, _, _, _, id, _, _, _, _, _) = item { id } else { nil } }
        #expect(ids.count == 11 && Set(ids).count == 11)
        #expect(ids.first == HyperliquidFillId(520_656_802_617_420))

        let stripped = String(decoding: Recording.body("Hyperliquid/fills-sub.json"), as: UTF8.self).replacingOccurrences(of: "\"tid\":520656802617420,", with: "")
        let withoutTid = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "userFillsByTime" ? .ok(Data(stripped.utf8)) : HyperliquidScannerTests.declaredOnlyRoute()(request, index)
        }
        let error = await sharedError { try await Hyperliquid.client(withoutTid).ledgerItems(account: "four-hour-2x", since: nil) }
        #expect(error?.meaning == "malformedResponse")
    }

    // The accounts: the main wallet the key is the agent of (userRole), by its address with no name, then each sub-account
    // the recorded subAccounts answer lists, by its address with its name, in Hyperliquid's order.
    @Test func theAccountsAreTheMainWalletThenItsSubAccountsByAddressWithTheirNames() async throws {
        let accounts = try await Hyperliquid.client(ReplaySession(route: Hyperliquid.route())).accounts()
        #expect(accounts == [ExchangeClientAccount(id: Hyperliquid.master, name: nil), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000103", name: "probe-churn"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000002", name: "four-hour-2x"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000104", name: "four-hour-1x"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000105", name: "fifteen-min-2x"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000106", name: "fifteen-min-1x"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000107", name: "five-min-2x"), ExchangeClientAccount(id: "0x0000000000000000000000000000000000000108", name: "five-min-1x")])
        // A ledger side's account is the same text, so a move to the sub-account is matched by it.
        let items = try await Hyperliquid.client(ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())).ledgerItems(account: "four-hour-2x", since: nil)
        let named = items.compactMap { item -> String? in
            guard case .internalMove(_, _, let to, _, _, _, _) = item else { return nil }
            return accounts.first { $0.id == to.account }?.name
        }
        #expect(named.contains("four-hour-2x"))
    }

    // userFees: the perpetuals pair (add rests, cross takes) then the spot pair, discounts included as stated.
    @Test func theFeeRatesAreThePerpetualsPairThenTheSpotPair() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let rates = try await Hyperliquid.client(session).feeRates(account: Hyperliquid.master)
        #expect(rates == [
            ExchangeClientFeeRate(scope: .perpetuals, maker: try WireDecimal(parsing: "0.000105").fraction(), taker: try WireDecimal(parsing: "0.000315").fraction()),
            ExchangeClientFeeRate(scope: .spot, maker: try WireDecimal(parsing: "0.00028").fraction(), taker: try WireDecimal(parsing: "0.00049").fraction())
        ])
        let sent = session.requests.compactMap { $0.jsonBody }.first { $0["type"] as? String == "userFees" }
        #expect(sent?["user"] as? String == Hyperliquid.master)
    }

    // MARK: The funding read's pages and a folded day's payments (fosline's request of 2026-10-20: a read from the start
    // on an old sub-account stopped at the exchange's 500th item, the last days missing, and `nSamples` was dropped)

    // The recorded sub-account's funding is 500 items, Hyperliquid's documented cap on a windowed answer, the last at
    // 1_790_971_200_006 (one item, ETH): the client asks again from that millisecond; this second page holds that item
    // again, which it drops, and three later payments, which it keeps. A third page from the last of those is empty.
    static let fundingLast: Int64 = 1_790_971_200_006
    static func fundingPage(at time: Int64, coin: String, usdc: String, samples: String = "null") -> String {
        #"{"time":\#(time),"hash":"0x0000000000000000000000000000000000000109000000000000000000000023","delta":{"type":"funding","coin":"\#(coin)","usdc":"\#(usdc)","szi":"0.0089","fundingRate":"0.0000125","nSamples":\#(samples)}}"#
    }
    static func pagedFunding() -> ReplaySession {
        let page1 = Recording.body("Hyperliquid/funding-sub.json")
        let page2 = Data("[\(fundingPage(at: fundingLast, coin: "ETH", usdc: "0.00069")),\(fundingPage(at: fundingLast + 3_600_000, coin: "ETH", usdc: "0.0007")),\(fundingPage(at: fundingLast + 7_200_000, coin: "ETH", usdc: "0.0008")),\(fundingPage(at: fundingLast + 7_200_000, coin: "BNB", usdc: "0.0009"))]".utf8)
        let route = HyperliquidScannerTests.declaredOnlyRoute()
        return ReplaySession { request, index in
            guard request.jsonBody["type"] as? String == "userFunding" else { return route(request, index) }
            switch request.jsonBody["startTime"] as? Int64 {
            case .some(0): return .ok(page1)
            case .some(fundingLast): return .ok(page2)
            default: return .ok(Data("[]".utf8))
            }
        }
    }

    @Test func theFundingReadWalksTheExchangesPagesToTheEnd() async throws {
        let session = Self.pagedFunding()
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        #expect(items.count == 11 + 503 + 4)
        let starts = session.requests.filter { $0.jsonBody["type"] as? String == "userFunding" }.map { $0.jsonBody["startTime"] as? Int64 }
        #expect(starts == [0, Self.fundingLast])
        let funding = items.compactMap { item -> (Date, Amount)? in
            if case let .funding(_, amount, _, time, _, _) = item { (time, amount) } else { nil }
        }
        // The boundary item once, then the three new payments, the two at one millisecond in coin order.
        #expect(funding.count { $0.0 == Date(wireMilliseconds: Self.fundingLast) } == 1)
        #expect(funding.suffix(3).map(\.1) == [Amount(baseUnits: 70_000, of: Hyperliquid.usdc), Amount(baseUnits: 90_000, of: Hyperliquid.usdc), Amount(baseUnits: 80_000, of: Hyperliquid.usdc)])
        let lastFunding = try #require(items.last { if case .funding = $0 { true } else { false } })
        #expect(Self.cursor(lastFunding) == HyperliquidLedgerCursor(milliseconds: Self.fundingLast + 7_200_000, place: 2))
    }

    // The recorded fills are 36, short of the documented 2000, and the moves 4: each read once. The funding read, 500,
    // is a full page, so it is asked once more from the last item's time, and the window's one repeat ends the walk.
    @Test func aPageShortOfTheCapIsTheLastAndAFullOneIsFollowed() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        #expect(items.count == 11 + 500 + 4)
        let types = session.requests.compactMap { $0.jsonBody["type"] as? String }
        #expect(types.count { $0 == "userFillsByTime" } == 1)
        #expect(types.count { $0 == "userNonFundingLedgerUpdates" } == 1)
        #expect(types.count { $0 == "userFunding" } == 2)
    }

    // A read from a cursor starts at the cursor's millisecond, as before, and still walks.
    @Test func aReadFromACursorStartsItsFirstPageThere() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let since = HyperliquidLedgerCursor(milliseconds: 1_790_467_200_025, place: 2)
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: since)
        let starts = session.requests.filter { $0.jsonBody["type"] as? String == "userFunding" }.map { $0.jsonBody["startTime"] as? Int64 }
        #expect(starts.first == since.milliseconds)
        #expect(items.allSatisfy { (Self.cursor($0).milliseconds, Self.cursor($0).place) > (since.milliseconds, since.place) })
    }

    // The recording's first item is ALGO's folded day of 2026-09-22, `nSamples` 24, stamped 00:00:00.000 UTC; the
    // payment of 2026-09-27 00:00:00.025 carries null. The item states the count the exchange stated, or none.
    @Test func aFoldedDayCarriesItsPaymentsCountAndAPaymentNone() async throws {
        let session = ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let day = try #require(items.first { if case .funding = $0 { true } else { false } })
        #expect(day == .funding(market: try HyperliquidMarketName(validating: "ALGO"), amount: Amount(baseUnits: -637_900, of: Hyperliquid.usdc),
                                rate: try WireDecimal(parsing: "0.0000125").fraction(), time: Date(wireMilliseconds: 1_790_035_200_000),
                                cursor: HyperliquidLedgerCursor(milliseconds: 1_790_035_200_000, place: 1), payments: 24))
        let payment = try #require(items.first { if case let .funding(_, _, _, time, _, _) = $0 { time == Date(wireMilliseconds: 1_790_467_200_025) } else { false } })
        guard case let .funding(_, _, _, _, _, payments) = payment else { return }
        #expect(payments == nil)
    }

    // MARK: A ledger update's fee (fosline's request of 2026-10-19: the faucet's internalTransfer of 1,000 USDC carried
    // `fee: "1.0"`, which the client dropped)

    // The main account's ledger alone: its recorded updates, no fills, no funding.
    static func masterLedger(_ updates: Data = Recording.body("Hyperliquid/ledger-master.json")) -> ReplaySession {
        ReplaySession { request, index in
            switch request.jsonBody["type"] as? String {
            case "userFillsByTime", "userFunding": .ok(Data("[]".utf8))
            case "userNonFundingLedgerUpdates": .ok(updates)
            default: Hyperliquid.route()(request, index)
            }
        }
    }

    static let faucet = "0x00000000000000000000000000000000000000f0"

    @Test func anInternalTransferCarriesItsFeeAndItsAmountAsStated() async throws {
        let items = try await Hyperliquid.client(Self.masterLedger()).ledgerItems(account: Hyperliquid.master, since: nil)
        let first = try #require(items.first)
        #expect(first == .internalMove(try Amount(whole: 1_000, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Self.faucet, wallet: .perpetuals), to: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals),
                                       id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000200"), time: Date(wireMilliseconds: 1_791_550_794_933),
                                       cursor: HyperliquidLedgerCursor(milliseconds: 1_791_550_794_933, place: 1),
                                       fee: try Amount(whole: 1, of: Hyperliquid.usdc)))
    }

    @Test func aSendWithinOneAccountIsAMoveBetweenItsWalletsNamingTheAccountOnBothSidesWithItsStatedZeroFee() async throws {
        let items = try await Hyperliquid.client(Self.masterLedger()).ledgerItems(account: Hyperliquid.master, since: nil)
        // sourceDex "spot", destinationDex "" (the perpetuals dex); user and destination both the main account.
        #expect(items[1] == .internalMove(Amount(baseUnits: 92_424_000_000, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .spot), to: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals),
                                          id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000201"), time: Date(wireMilliseconds: 1_791_555_526_034),
                                          cursor: HyperliquidLedgerCursor(milliseconds: 1_791_555_526_034, place: 1),
                                          fee: .zero(of: Hyperliquid.usdc)))
    }

    @Test func aSubAccountTransferStatesNoFee() async throws {
        let items = try await Hyperliquid.client(Self.masterLedger()).ledgerItems(account: Hyperliquid.master, since: nil)
        #expect(items[2] == .internalMove(try Amount(whole: 100, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals), to: ExchangeClientLedgerSide(account: Hyperliquid.sub, wallet: .perpetuals),
                                          id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000202"), time: Date(wireMilliseconds: 1_791_576_041_830),
                                          cursor: HyperliquidLedgerCursor(milliseconds: 1_791_576_041_830, place: 1)))
    }

    // Constructed from the documented update kinds (info endpoint, userNonFundingLedgerUpdates): a withdrawal with its
    // fee, a send between two accounts, a send of another token and a send whose fee is in another token.
    @Test func aWithdrawalCarriesItsFeeAndASendBetweenAccountsNamesTheirAddresses() async throws {
        let updates = Data("""
        [{"time":1,"hash":"0x0000000000000000000000000000000000000000000000000000000000000001","delta":{"type":"withdraw","usdc":"50.0","nonce":1,"fee":"1.0"}},
         {"time":2,"hash":"0x0000000000000000000000000000000000000000000000000000000000000002","delta":{"type":"send","user":"\(Hyperliquid.master)","destination":"\(Hyperliquid.sub)","sourceDex":"","destinationDex":"","token":"USDC","amount":"5.0","usdcValue":"5.0","fee":"0.1","nativeTokenFee":"0.0","nonce":2,"feeToken":""}},
         {"time":3,"hash":"0x0000000000000000000000000000000000000000000000000000000000000003","delta":{"type":"send","user":"\(Hyperliquid.master)","destination":"\(Hyperliquid.sub)","sourceDex":"spot","destinationDex":"spot","token":"HYPE","amount":"2.0","usdcValue":"60.0","fee":"0.0","nativeTokenFee":"0.0","nonce":3,"feeToken":""}},
         {"time":4,"hash":"0x0000000000000000000000000000000000000000000000000000000000000004","delta":{"type":"send","user":"\(Hyperliquid.master)","destination":"\(Hyperliquid.sub)","sourceDex":"","destinationDex":"","token":"USDC","amount":"5.0","usdcValue":"5.0","fee":"0.0","nativeTokenFee":"0.01","nonce":4,"feeToken":"HYPE"}}]
        """.utf8)
        let items = try await Hyperliquid.client(Self.masterLedger(updates)).ledgerItems(account: Hyperliquid.master, since: nil)
        #expect(items == [
            .withdrawal(try Amount(whole: 50, of: Hyperliquid.usdc), id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000001"), time: Date(wireMilliseconds: 1),
                        cursor: HyperliquidLedgerCursor(milliseconds: 1, place: 1), fee: try Amount(whole: 1, of: Hyperliquid.usdc), wallet: .perpetuals),
            .internalMove(try Amount(whole: 5, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals), to: ExchangeClientLedgerSide(account: Hyperliquid.sub, wallet: .perpetuals),
                          id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000002"), time: Date(wireMilliseconds: 2),
                          cursor: HyperliquidLedgerCursor(milliseconds: 2, place: 1), fee: Amount(baseUnits: 10_000_000, of: Hyperliquid.usdc))
        ])
    }

    // David's ruling of 2026-10-19 (via fosline): a movement carries the exchange's own id, required. Hyperliquid's is
    // the update's hash; one without a hash, or with an all-zero one, refuses the read.
    @Test func aMoveBetweenTheMainAccountAndASubAccountCarriesTheSameHashInBoth() async throws {
        let items = try await Hyperliquid.client(ReplaySession(route: HyperliquidScannerTests.declaredOnlyRoute())).ledgerItems(account: "four-hour-2x", since: nil)
        let ids = items.compactMap { item -> HyperliquidTransferId? in
            guard case .internalMove(_, _, _, let id, _, _, _) = item else { return nil }
            return id
        }
        #expect(ids == [try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000109000000000000000000000024"),
                        try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000109000000000000000000000025"),
                        try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000109000000000000000000000026"),
                        try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000109000000000000000000000027")])
    }

    // MARK: Wallets and sides

    // Constructed from the documented update kinds: a deposit lands on the perpetuals wallet; an accountClassTransfer
    // names no account, its sides the one account's wallets by toPerp; a spotTransfer (the older spot send, 2141 of
    // them against 130 sends among 24 mainnet users probed 2026-10-25) is on the spot wallet at both ends; a send to a
    // builder dex names the dex.
    @Test func aDepositLandsOnThePerpetualsWalletAndEachMoveNamesItsSidesAsStated() async throws {
        let updates = Data("""
        [{"time":1,"hash":"0x0000000000000000000000000000000000000000000000000000000000000001","delta":{"type":"deposit","usdc":"20945.92"}},
         {"time":2,"hash":"0x0000000000000000000000000000000000000000000000000000000000000002","delta":{"type":"accountClassTransfer","usdc":"60.0","toPerp":true}},
         {"time":3,"hash":"0x0000000000000000000000000000000000000000000000000000000000000003","delta":{"type":"accountClassTransfer","usdc":"10.0","toPerp":false}},
         {"time":4,"hash":"0x0000000000000000000000000000000000000000000000000000000000000004","delta":{"type":"spotTransfer","token":"USDC","amount":"74032.658254","usdcValue":"74032.658254","user":"\(Hyperliquid.master)","destination":"\(Hyperliquid.sub)","fee":"0.0","nativeTokenFee":"0.0","nonce":4,"feeToken":""}},
         {"time":5,"hash":"0x0000000000000000000000000000000000000000000000000000000000000005","delta":{"type":"send","user":"\(Hyperliquid.master)","destination":"\(Hyperliquid.master)","sourceDex":"","destinationDex":"xyz","token":"USDC","amount":"997.836383","usdcValue":"997.836383","fee":"0.0","nativeTokenFee":"0.0","nonce":5,"feeToken":""}}]
        """.utf8)
        let items = try await Hyperliquid.client(Self.masterLedger(updates)).ledgerItems(account: Hyperliquid.master, since: nil)
        let own = { (wallet: ExchangeClientWallet) in ExchangeClientLedgerSide(account: nil, wallet: wallet) }
        #expect(items == [
            .deposit(Amount(baseUnits: 2_094_592_000_000, of: Hyperliquid.usdc), id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000001"), time: Date(wireMilliseconds: 1),
                     cursor: HyperliquidLedgerCursor(milliseconds: 1, place: 1), wallet: .perpetuals),
            .internalMove(try Amount(whole: 60, of: Hyperliquid.usdc), from: own(.spot), to: own(.perpetuals), id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000002"),
                          time: Date(wireMilliseconds: 2), cursor: HyperliquidLedgerCursor(milliseconds: 2, place: 1)),
            .internalMove(try Amount(whole: 10, of: Hyperliquid.usdc), from: own(.perpetuals), to: own(.spot), id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000003"),
                          time: Date(wireMilliseconds: 3), cursor: HyperliquidLedgerCursor(milliseconds: 3, place: 1)),
            .internalMove(Amount(baseUnits: 7_403_265_825_400, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .spot), to: ExchangeClientLedgerSide(account: Hyperliquid.sub, wallet: .spot),
                          id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000004"), time: Date(wireMilliseconds: 4),
                          cursor: HyperliquidLedgerCursor(milliseconds: 4, place: 1), fee: .zero(of: Hyperliquid.usdc)),
            .internalMove(Amount(baseUnits: 99_783_638_300, of: Hyperliquid.usdc), from: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .perpetuals), to: ExchangeClientLedgerSide(account: Hyperliquid.master, wallet: .named("xyz")),
                          id: try HyperliquidTransferId(validating: "0x0000000000000000000000000000000000000000000000000000000000000005"), time: Date(wireMilliseconds: 5),
                          cursor: HyperliquidLedgerCursor(milliseconds: 5, place: 1), fee: .zero(of: Hyperliquid.usdc))
        ])
    }

    // Mainnet lists spot fills beside the perpetuals' (coin "@334", "PURR/USDC"; 5454 and 1035 of them against 4845
    // perpetuals fills among 24 users probed 2026-10-25). The client declares no spot token, so such a fill is passed
    // over, and the wallet's perpetuals fills read; a perpetual in an undeclared
    // coin still refuses the read.
    @Test func aSpotFillIsPassedOverAndThePerpetualsFillsReadWithTheirWallet() async throws {
        let spot = """
        {"coin":"@107","px":"38.5","sz":"2.0","side":"B","time":1790568059000,"startPosition":"0.0","dir":"Buy","closedPnl":"0.0","hash":"0x00000000000000000000000000000000000001090000000000000000000000f1","oid":61246678000,"crossed":true,"fee":"0.0539","tid":100000000000001,"feeToken":"USDC","twapId":null},\
        {"coin":"PURR/USDC","px":"0.096959","sz":"179.0","side":"A","time":1790568059001,"startPosition":"179.0","dir":"Sell","closedPnl":"0.0","hash":"0x00000000000000000000000000000000000001090000000000000000000000f2","oid":61246678001,"crossed":true,"fee":"0.012","tid":100000000000002,"feeToken":"USDC","twapId":null},
        """
        let fills = String(decoding: HyperliquidScannerTests.kept("fills-sub.json", coins: ["ETH"]), as: UTF8.self).replacingOccurrences(of: "[{", with: "[" + spot + "{")
        let route = HyperliquidScannerTests.declaredOnlyRoute()
        let session = ReplaySession(route: { request, index in
            request.jsonBody["type"] as? String == "userFillsByTime" ? .ok(Data(fills.utf8)) : route(request, index)
        })
        let items = try await Hyperliquid.client(session).ledgerItems(account: "four-hour-2x", since: nil)
        let wallets = items.compactMap { item -> ExchangeClientWallet?? in
            guard case .fill(_, _, _, _, _, _, _, _, _, _, _, let wallet) = item else { return nil }
            return .some(wallet)
        }
        #expect(wallets.count == 11 && wallets.allSatisfy { $0 == .perpetuals })
    }

    @Test(arguments: [#""hash":null,"#, "", #""hash":"0x0000000000000000000000000000000000000000000000000000000000000000","#, #""hash":"0x01","#])
    func aMovementWithoutAHashRefusesTheRead(hash: String) async throws {
        let updates = Data(#"[{"time":1,\#(hash)"delta":{"type":"deposit","usdc":"5.0"}}]"#.utf8)
        let error = await sharedError { try await Hyperliquid.client(Self.masterLedger(updates)).ledgerItems(account: Hyperliquid.master, since: nil) }
        #expect(error?.meaning == "malformedResponse")
    }

    @Test func theTransferIdRoundTripsThroughJSONAndRefusesAMalformedHash() throws {
        let id = try HyperliquidTransferId(validating: "0x4afdf4262828628d4c77042b49a3a20000390c0bc32b815feec69f78e72c3c77")
        #expect(try id.toJSON().fromJSON() == id)
        #expect(throws: (any Error).self) { let _: HyperliquidTransferId = try #""0xabc""#.fromJSON() }
    }

    // MARK: The spot wallet (fosline's request of 2026-10-19: the main account's 0.004058 USDC on spot, which the
    // perpetuals' value does not hold)

    @Test func theSpotWalletsUSDCIsReadInTheUSDCHolding() async throws {
        let session = ReplaySession(route: Hyperliquid.route())
        let holdings = try await Hyperliquid.client(session).holdings(account: Hyperliquid.master)
        #expect(holdings == [ExchangeClientHolding(name: "USDC", instance: Hyperliquid.usdc,
                                                   total: Amount(baseUnits: 405_800, of: Hyperliquid.usdc), held: .zero(of: Hyperliquid.usdc))])
        let asked = try #require(session.requests.last { $0.jsonBody["type"] as? String == "spotClearinghouseState" })
        #expect(asked.jsonBody["user"] as? String == Hyperliquid.master)
    }

    // Constructed from the documented spotClearinghouseState: USDC held for an order, and PURR, token 1.
    @Test func anotherSpotTokenIsListedByItsNameWithNoAmount() async throws {
        let body = Data(#"{"balances":[{"coin":"USDC","token":0,"hold":"5.0","total":"14.625485","entryNtl":"0.0"},{"coin":"PURR","token":1,"hold":"0.0","total":"2000","entryNtl":"1234.56"}]}"#.utf8)
        let session = ReplaySession { request, index in
            request.jsonBody["type"] as? String == "spotClearinghouseState" ? .ok(body) : Hyperliquid.route()(request, index)
        }
        let holdings = try await Hyperliquid.client(session).holdings(account: Hyperliquid.master)
        #expect(holdings == [
            ExchangeClientHolding(name: "USDC", instance: Hyperliquid.usdc, total: Amount(baseUnits: 1_462_548_500, of: Hyperliquid.usdc),
                                  held: try Amount(whole: 5, of: Hyperliquid.usdc)),
            ExchangeClientHolding(name: "PURR", instance: nil, total: nil, held: nil)
        ])
    }

    // Spot states USDC to eight places, and the holding is declared at eight (the owner's ruling of 2026-10-19): a
    // spot total at eight reads exactly; one finer than eight is refused, never rounded.
    @Test func aSpotUSDCAtEightPlacesReadsExactlyAndAFinerOneIsRefused() async throws {
        func read(_ total: String) async throws -> [ExchangeClientHolding] {
            let body = Data(#"{"balances":[{"coin":"USDC","token":0,"hold":"0.0","total":"\#(total)","entryNtl":"0.0"}]}"#.utf8)
            let session = ReplaySession { request, index in
                request.jsonBody["type"] as? String == "spotClearinghouseState" ? .ok(body) : Hyperliquid.route()(request, index)
            }
            return try await Hyperliquid.client(session).holdings(account: Hyperliquid.master)
        }
        #expect(try await read("0.00405812").first?.total == Amount(baseUnits: 405_812, of: Hyperliquid.usdc))
        await #expect(throws: ExchangeClientError.self) { try await read("0.004058123") }
    }

    static func cursor(_ item: ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidFillId, HyperliquidTransferId, HyperliquidLedgerCursor>) -> HyperliquidLedgerCursor {
        switch item {
        case .fill(_, _, _, _, _, _, _, _, _, let cursor, _, _), .funding(_, _, _, _, let cursor, _),
             .deposit(_, _, _, let cursor, _, _), .withdrawal(_, _, _, let cursor, _, _), .internalMove(_, _, _, _, _, let cursor, _): cursor
        }
    }
}
