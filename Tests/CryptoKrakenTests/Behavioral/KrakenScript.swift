// KrakenScript.swift — Kraken's wire, scripted for C31's contract.
//
// ASSUMED SHAPE, every body in this file: Kraken's derivatives REST (perpetuals, isolated leverage, a demo market),
// written from its public shape as known without a recording (no web, no POC opened). Kraken sends its numbers as
// JSON NUMBERS, so these bodies also prove that a JSON number's text is parsed exactly, never through a Double.
// The builder replaces a body with a recorded one where they differ and keeps the expected value.

import CryptoAsset
import CryptoExchange
import CryptoKraken
import Foundation
import Testing

struct KrakenScript: ExchangeClientScript {
    typealias Client = KrakenClient

    static let apiKey = "scripted-kraken-api-key-0001"
    static let secretBase64 = "c2NyaXB0ZWQta3Jha2VuLXNlY3JldC1uZXZlci1hLXJlYWwtb25l"
    static let secretRaw = "scripted-kraken-secret-never-a-real-one"

    func makeClient(session: ScriptedSession, log: LogCapture) throws -> KrakenClient {
        try KrakenClient(credential: .apiKey(Self.apiKey, secret: Self.secretBase64), endpoint: .testMarket, session: session, log: { log.record($0) }) // INVENTED: KrakenClient's initializer, after C31's Hyperliquid example; the `.apiKey(_:secret:)` credential (AR32); the `log:` parameter
    }

    var secretTexts: [String] { [Self.secretBase64, Self.secretRaw] }
    var keyIdentifierTexts: [String] { [Self.apiKey] }
    var market: KrakenClient.MarketName { "PF_XBTUSD" }
    var account: String { "flex" }

    static func orderId(_ text: String) throws -> KrakenClient.OrderId { try decoded(KrakenClient.OrderId.self, json: "\"\(text)\"") }

    static let instruments = ScriptedRoute.json("instruments", """
    {"result":"success","instruments":[{"symbol":"PF_XBTUSD","type":"flexible_futures","base":"XBT","quote":"USD","tickSize":0.5,\
    "contractSize":1,"tradeable":true,"contractValueTradePrecision":4,"marginLevels":[{"contracts":0,"initialMargin":0.02,"maintenanceMargin":0.01}],\
    "maxPositionSize":1000000,"openingDate":"2022-01-01T00:00:00.000Z"}],"serverTime":"2024-09-22T10:13:20.000Z"}
    """)

    static let tickers = ScriptedRoute.json("tickers", """
    {"result":"success","tickers":[{"symbol":"PF_XBTUSD","last":64250.4,"markPrice":64250.6,"bid":64250.0,"ask":64251.0,\
    "vol24h":9007199254740993,"fundingRate":0.0000125,"suspended":false,"tag":"perpetual","pair":"XBT:USD"}],"serverTime":"2024-09-22T10:13:20.000Z"}
    """)

    static let orderbook = ScriptedRoute.json("orderbook", """
    {"result":"success","orderBook":{"bids":[[64250.0,1.2],[64249.5,2.0]],"asks":[[64251.0,0.8],[64252.0,3.1]]},"serverTime":"2024-09-22T10:13:20.123Z"}
    """)

    static var info: [ScriptedRoute] { [instruments, tickers, orderbook] }

    // MARK: markets, book

    func marketsCase() throws -> ScriptedCase<[ExchangeClientMarket<KrakenClient.MarketName>]> {
        ScriptedCase(
            routes: Self.info,
            expected: [
                // READING: Kraken's XBT is the asset BTC; the minimum is one lot; the leverage is 1 / the first initial margin
                try makeMarket("PF_XBTUSD", base: "BTC", quote: "USD", lotSize: amount("0.0001", "BTC"), minimumOrder: amount("0.0001", "BTC"), maxLeverage: 50, leverageSet: nil, isPerpetual: true),
            ]
        )
    }

    func bookCase() throws -> ScriptedCase<ExchangeClientBook<KrakenClient.MarketName>> {
        ScriptedCase(
            routes: Self.info,
            // the mid is the best bid and ask halved, exactly; READING: the volume is the day's in contracts of the base,
            // 2^53 + 1 sent as a JSON number, which no Double holds
            expected: makeBook("PF_XBTUSD", mid: try price("64250.5", "USD"), bestBid: try price("64250.0", "USD"), bestAsk: try price("64251.0", "USD"), volume: try amount("9007199254740993", "BTC"), readAt: try iso("2024-09-22T10:13:20.123Z")),
            sent: ["PF_XBTUSD"]
        )
    }

    // MARK: orders

    private func order(_ sendStatus: String, expected: OrderOutcome<KrakenClient.OrderId>, code: String? = nil) throws -> OrderCase<KrakenClient> {
        OrderCase(
            side: .buy, size: try amount("0.0012", "BTC"), limit: try price("64300.5", "USD"),
            routes: Self.info + [.json("sendorder", #"{"result":"success","sendStatus":\#(sendStatus),"serverTime":"2024-09-22T10:13:21.000Z"}"#)],
            expected: expected,
            expectedRefusalCode: code,
            sent: ["orderType=ioc", "symbol=PF_XBTUSD", "side=buy", "size=0.0012", "limitPrice=64300.5", "reduceOnly=false"]
        )
    }

    private static func execution(_ id: String, _ amount: String) -> String {
        #"{"order_id":"\#(id)","status":"placed","receivedTime":"2024-09-22T10:13:21.000Z","orderEvents":[{"type":"EXECUTION","executionId":"e-\#(id.prefix(4))","price":64250.4,"amount":\#(amount),"orderPriorExecution":{"orderId":"\#(id)","quantity":0.0012,"filled":0,"limitPrice":64300.5,"side":"buy","type":"ioc","symbol":"PF_XBTUSD"}}]}"#
    }

    func filledOrder() throws -> OrderCase<KrakenClient> {
        try order(Self.execution("c18f0c17-9971-40e6-8e5b-10df05d422f0", "0.0012"),
                  expected: .filled(units: try amount("0.0012", "BTC"), at: try price("64250.4", "USD"), id: try Self.orderId("c18f0c17-9971-40e6-8e5b-10df05d422f0")))
    }

    func partlyFilledOrder() throws -> OrderCase<KrakenClient> {
        try order(Self.execution("0b7d1c55-2d5e-4c38-9a4e-3a3f0f6f1e01", "0.0006"),
                  expected: .partlyFilled(units: try amount("0.0006", "BTC"), at: try price("64250.4", "USD"), id: try Self.orderId("0b7d1c55-2d5e-4c38-9a4e-3a3f0f6f1e01")))
    }

    func unmatchedOrder() throws -> OrderCase<KrakenClient> {
        // READING: Kraken's iocWouldNotExecute carries no order id: cancelled before accepted
        try order(#"{"status":"iocWouldNotExecute","receivedTime":"2024-09-22T10:13:21.000Z","orderEvents":[]}"#, expected: .cancelledBeforeAccepted)
    }

    func refusedOrder() throws -> OrderCase<KrakenClient> {
        // READING: Kraken's status is both the code and the only text it sends
        try order(#"{"status":"insufficientAvailableFunds","receivedTime":"2024-09-22T10:13:21.000Z","orderEvents":[]}"#,
                  expected: .refused(text: "insufficientAvailableFunds"), code: "insufficientAvailableFunds")
    }

    func quietOrderRoutes() throws -> (routes: [ScriptedRoute], orderNeedle: String) {
        (Self.info + [.unreachable("sendorder")], "sendorder")
    }

    func openOrdersCase() throws -> ScriptedCase<[ExchangeClientOpenOrder<KrakenClient.MarketName, KrakenClient.OrderId>]> {
        ScriptedCase(
            routes: Self.info + [.json("openorders", """
            {"result":"success","openOrders":[{"order_id":"2ce038ae-c144-4de7-a0f1-82f7f4fca864","symbol":"PF_XBTUSD","side":"buy",\
            "orderType":"lmt","limitPrice":60000.5,"unfilledSize":0.002,"receivedTime":"2024-09-22T10:13:19.000Z","status":"untouched",\
            "filledSize":0,"reduceOnly":false}],"serverTime":"2024-09-22T10:13:20.000Z"}
            """)],
            expected: [makeOpenOrder(try Self.orderId("2ce038ae-c144-4de7-a0f1-82f7f4fca864"), market: "PF_XBTUSD", side: .buy, units: try amount("0.002", "BTC"))]
        )
    }

    func cancelCase() throws -> (id: KrakenClient.OrderId, scripted: ScriptedCase<Void>) {
        (try Self.orderId("2ce038ae-c144-4de7-a0f1-82f7f4fca864"),
         ScriptedCase(routes: Self.info + [.json("cancelorder", #"{"result":"success","cancelStatus":{"status":"cancelled","order_id":"2ce038ae-c144-4de7-a0f1-82f7f4fca864","receivedTime":"2024-09-22T10:13:22.000Z"},"serverTime":"2024-09-22T10:13:22.000Z"}"#)],
                      expected: (), sent: ["2ce038ae-c144-4de7-a0f1-82f7f4fca864"]))
    }

    func cancelGoneCase() throws -> (id: KrakenClient.OrderId, error: ErrorCase) {
        // READING: the status is the code and the text
        (try Self.orderId("9f0e8d7c-6b5a-4f3e-8d2c-1b0a9f8e7d6c"),
         ErrorCase(routes: Self.info + [.json("cancelorder", #"{"result":"success","cancelStatus":{"status":"notFound","receivedTime":"2024-09-22T10:13:22.000Z"},"serverTime":"2024-09-22T10:13:22.000Z"}"#)],
                   expected: .exchange(code: "notFound", text: "notFound"))) // INVENTED: ExchangeClientError.exchange(code:text:)
    }

    // MARK: account

    func accountStateCase() throws -> ScriptedCase<ExchangeClientAccountState<KrakenClient.MarketName>> {
        ScriptedCase(
            routes: Self.info + [
                .json("accounts", """
                {"result":"success","accounts":{"flex":{"type":"multiCollateralMarginAccount","currencies":{"USD":{"quantity":1523.456789,\
                "value":1523.456789,"collateral":1523.456789,"available":1200.5}},"initialMargin":128.5,"balanceValue":1523.456789,\
                "portfolioValue":1520.950789,"collateralValue":1523.456789,"pnl":-2.506,"unrealizedFunding":0,"totalUnrealized":-2.506,\
                "availableMargin":1200.5,"marginEquity":1520.950789}},"serverTime":"2024-09-22T10:13:20.456Z"}
                """),
                .json("openpositions", """
                {"result":"success","openPositions":[{"side":"short","symbol":"PF_XBTUSD","price":64000.0,"fillTime":"2024-09-22T09:00:00.000Z",\
                "size":0.01,"unrealizedFunding":0.0001,"pnlCurrency":"USD"}],"serverTime":"2024-09-22T10:13:20.456Z"}
                """),
            ],
            expected: makeAccountState(
                balance: try amount("1523.456789", "USD"),
                // READING: what can leave is the available margin
                withdrawable: try amount("1200.5", "USD"),
                // READING: the mark is the ticker's; Kraken sends no liquidation price here
                positions: [makePosition("PF_XBTUSD", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USD"), mark: try price("64250.6", "USD"), liquidationPrice: nil)],
                // READING: the account's type is the mode's name; it transfers and holds isolated positions; no alternative is listed
                mode: makeMode("multiCollateralMarginAccount", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: []),
                readAt: try iso("2024-09-22T10:13:20.456Z")
            )
        )
    }

    // MARK: ledger: the fills (order ids) joined with the account log (fees, funding, moves) by execution

    private static func log(_ id: Int, _ date: String, _ info: String, old: String, new: String, fee: String = "null", funding: String = "null", rate: String = "null", execution: String = "null", contract: String = "null") -> String {
        #"{"id":\#(id),"date":"\#(date)","asset":"usd","info":"\#(info)","booking_uid":"b\#(id)","margin_account":"f-flex","old_balance":\#(old),"new_balance":\#(new),"realized_pnl":null,"fee":\#(fee),"execution":\#(execution),"collateral":"USD","funding_rate":\#(rate),"realized_funding":\#(funding),"contract":\#(contract)}"#
    }

    private static func fill(_ fillId: String, _ orderId: String, side: String, size: String, price: String, time: String, type: String) -> String {
        #"{"fill_id":"\#(fillId)","symbol":"PF_XBTUSD","side":"\#(side)","order_id":"\#(orderId)","size":\#(size),"price":\#(price),"fillTime":"\#(time)","fillType":"\#(type)"}"#
    }

    private static let deposit = log(1201, "2024-09-22T10:13:20.500Z", "cross-exchange transfer", old: "0", new: "1000")
    private static let tradeLog = log(1202, "2024-09-22T10:13:21.000Z", "futures trade", old: "1000", new: "999.976288", fee: "-0.023712", execution: "\"e1\"", contract: "\"PF_XBTUSD\"")
    private static let fundingLog = log(1203, "2024-09-22T10:13:22.000Z", "funding rate change", old: "999.976288", new: "999.960988", funding: "-0.0153", rate: "0.0000125", contract: "\"PF_XBTUSD\"")
    private static let withdrawalLog = log(1204, "2024-09-22T10:13:22.500Z", "cross-exchange transfer", old: "999.960988", new: "899.960988")
    private static let sameInstantTradeLog = log(1205, "2024-09-22T10:13:22.000Z", "futures trade", old: "899.960988", new: "899.951349", fee: "-0.009639", execution: "\"e2\"", contract: "\"PF_XBTUSD\"")
    private static let liquidationLog = log(1206, "2024-09-22T10:13:23.000Z", "futures liquidation", old: "899.951349", new: "899.601349", fee: "-0.35", execution: "\"e3\"", contract: "\"PF_XBTUSD\"")

    private static let fill1 = fill("e1", "c18f0c17-9971-40e6-8e5b-10df05d422f0", side: "buy", size: "0.0012", price: "64250.4", time: "2024-09-22T10:13:21.000Z", type: "taker")
    private static let fill2 = fill("e2", "5e9a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b", side: "sell", size: "0.0005", price: "64260.0", time: "2024-09-22T10:13:22.000Z", type: "taker")
    private static let fill3 = fill("e3", "7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", side: "buy", size: "0.01", price: "70123.4", time: "2024-09-22T10:13:23.000Z", type: "liquidation")

    func ledgerCase() throws -> LedgerCase<KrakenClient> {
        typealias Line = LedgerLine<KrakenClient.MarketName, KrakenClient.OrderId>
        let deposit = Line.deposit(try amount("1000", "USD"), time: try iso("2024-09-22T10:13:20.500Z"))
        // READING: a fee paid is a positive amount, whatever sign the exchange's log gives it
        let trade = Line.fill(market: "PF_XBTUSD", side: .buy, units: try amount("0.0012", "BTC"), price: try price("64250.4", "USD"), fee: try amount("0.023712", "USD"), order: try Self.orderId("c18f0c17-9971-40e6-8e5b-10df05d422f0"), closedBy: nil, time: try iso("2024-09-22T10:13:21.000Z"))
        let funding = Line.funding(market: "PF_XBTUSD", amount: try amount("-0.0153", "USD"), rate: try fraction("0.0000125"), time: try iso("2024-09-22T10:13:22.000Z"))
        let withdrawal = Line.withdrawal(try amount("100", "USD"), time: try iso("2024-09-22T10:13:22.500Z"))
        let sameInstant = Line.fill(market: "PF_XBTUSD", side: .sell, units: try amount("0.0005", "BTC"), price: try price("64260.0", "USD"), fee: try amount("0.009639", "USD"), order: try Self.orderId("5e9a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b"), closedBy: nil, time: try iso("2024-09-22T10:13:22.000Z"))
        let liquidation = Line.fill(market: "PF_XBTUSD", side: .buy, units: try amount("0.01", "BTC"), price: try price("70123.4", "USD"), fee: try amount("0.35", "USD"), order: try Self.orderId("7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"), closedBy: .liquidation, time: try iso("2024-09-22T10:13:23.000Z"))

        // the exchange answers newest first; the client hands up oldest first
        return LedgerCase(
            firstRoutes: Self.info + [
                .json("account-log", #"{"accountUid":"u1","logs":[\#(Self.withdrawalLog),\#(Self.fundingLog),\#(Self.tradeLog),\#(Self.deposit)]}"#),
                .json("fills", #"{"result":"success","fills":[\#(Self.fill1)],"serverTime":"2024-09-22T10:13:23.000Z"}"#),
            ],
            firstExpected: [deposit, trade, funding, withdrawal],
            // resumed after the funding (id 1203); the answer repeats it
            resumeAfter: 2,
            resumeRoutes: Self.info + [
                .json("account-log", #"{"accountUid":"u1","logs":[\#(Self.liquidationLog),\#(Self.sameInstantTradeLog),\#(Self.withdrawalLog),\#(Self.fundingLog)]}"#),
                .json("fills", #"{"result":"success","fills":[\#(Self.fill3),\#(Self.fill2),\#(Self.fill1)],"serverTime":"2024-09-22T10:13:23.000Z"}"#),
            ],
            resumeExpected: [sameInstant, withdrawal, liquidation],
            resumeSent: ["1203"]
        )
    }

    // MARK: leverage, transfer, key

    func leverageCase() throws -> (leverage: Int, scripted: ScriptedCase<Void>) {
        (5, ScriptedCase(routes: Self.info + [.json("leveragepreferences", #"{"result":"success","serverTime":"2024-09-22T10:13:20.000Z"}"#)],
                         expected: (), sent: ["maxLeverage=5", "PF_XBTUSD"]))
    }

    func transferCase() throws -> (amount: Amount, from: String, to: String, scripted: ScriptedCase<Void>) {
        (try amount("500.25", "USD"), "cash", "flex",
         ScriptedCase(routes: Self.info + [.json("/transfer", #"{"result":"success","serverTime":"2024-09-22T10:13:20.000Z"}"#)],
                      expected: (), sent: ["fromAccount=cash", "toAccount=flex", "amount=500.25"]))
    }

    func keyFactsCase() throws -> ScriptedCase<ExchangeClientKeyFacts> {
        // ASSUMED SHAPE and a READING: the projector does not know Kraken's key-permission endpoint; the builder maps this
        // body onto the one Kraken has. Kraken's keys have no approver and no expiry.
        ScriptedCase(
            routes: [.json("apikeys", #"{"result":"success","permissions":{"general":"full","trade":"full","transfer":"full","withdraw":"none"},"serverTime":"2024-09-22T10:13:20.000Z"}"#)],
            expected: makeKeyFacts(canTrade: true, canTransfer: true, canWithdraw: false, approvedBy: nil, validUntil: nil)
        )
    }

    // MARK: errors

    func rateLimitedCase() throws -> ErrorCase {
        ErrorCase(routes: [.json("", #"{"result":"error","error":"apiLimitExceeded"}"#, status: 429, headers: ["Retry-After": "7"])],
                  expected: .rateLimited(retryAfter: .seconds(7))) // INVENTED: ExchangeClientError.rateLimited(retryAfter:)
    }

    func malformedBookCase() throws -> ErrorCase {
        ErrorCase(routes: [Self.instruments, Self.tickers, .json("orderbook", #"{"result":"success","orderBook":{"bids":[["sixty-four thousand",1.2]],"asks":[[64251.0,0.8]]},"serverTime":"2024-09-22T10:13:20.123Z"}"#)],
                  expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func ambiguousNumberBookCase() throws -> ErrorCase {
        ErrorCase(routes: [Self.instruments, Self.tickers, .json("orderbook", #"{"result":"success","orderBook":{"bids":[["64,250.0",1.2]],"asks":[[64251.0,0.8]]},"serverTime":"2024-09-22T10:13:20.123Z"}"#)],
                  expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func unauthorizedOrderCase() throws -> ErrorCase {
        ErrorCase(routes: Self.info + [.json("sendorder", #"{"result":"error","error":"authenticationError","serverTime":"2024-09-22T10:13:21.000Z"}"#, status: 401)],
                  expected: .unauthorized) // INVENTED: ExchangeClientError.unauthorized
    }
}
