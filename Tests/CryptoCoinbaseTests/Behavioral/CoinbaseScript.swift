// CoinbaseScript.swift — Coinbase's wire, scripted for C31's contract.
//
// ASSUMED SHAPE, every body in this file: Coinbase's Advanced Trade REST with its international perpetuals,
// written from its public shape as known without a recording (no web, no POC opened). The funding and leverage
// routes are the least known of all and are marked again where they stand. The builder replaces a body with
// a recorded one where they differ and keeps the expected value.

import CryptoAsset
import CryptoCoinbase
import CryptoExchange
import Foundation
import Testing

struct CoinbaseScript: ExchangeClientScript {
    typealias Client = CoinbaseClient

    static let apiKey = "scripted-coinbase-api-key-0001"
    static let secret = "scripted-coinbase-secret-never-a-real-one"
    static let portfolio = "4f3c2b1a-0000-4000-8000-00000000c0b5"
    static let reserve = "4f3c2b1a-0000-4000-8000-0000000005e0"

    func makeClient(session: ScriptedSession, log: LogCapture) throws -> CoinbaseClient {
        try CoinbaseClient(credential: .apiKey(Self.apiKey, secret: Self.secret), endpoint: .testMarket, session: session, log: { log.record($0) }) // INVENTED: CoinbaseClient's initializer, after C31's Hyperliquid example; the `.apiKey(_:secret:)` credential (AR32); the `log:` parameter
    }

    var secretTexts: [String] { [Self.secret] }
    var keyIdentifierTexts: [String] { [Self.apiKey] }
    var market: CoinbaseClient.MarketName { "BTC-PERP-INTX" }
    var account: String { Self.portfolio }

    static func orderId(_ text: String) throws -> CoinbaseClient.OrderId { try decoded(CoinbaseClient.OrderId.self, json: "\"\(text)\"") }

    static let product = #"{"product_id":"BTC-PERP-INTX","price":"64250.5","volume_24h":"9007199254740993","base_increment":"0.0001","quote_increment":"0.1","base_min_size":"0.0001","quote_min_size":"10","base_currency_id":"BTC","quote_currency_id":"USDC","product_type":"FUTURE","trading_disabled":false,"future_product_details":{"contract_expiry_type":"PERPETUAL","perpetual_details":{"max_leverage":"20","funding_rate":"0.0000125"}}}"#

    static let productBook = ScriptedRoute.json("product_book", """
    {"pricebook":{"product_id":"BTC-PERP-INTX","bids":[{"price":"64250.0","size":"1.2"},{"price":"64249.5","size":"2.0"}],\
    "asks":[{"price":"64251.0","size":"0.8"},{"price":"64252.0","size":"3.1"}],"time":"2024-09-22T10:13:20.123Z"},\
    "last":"64250.4","mid_market":"64250.5","spread_bps":"0.16"}
    """)

    static var info: [ScriptedRoute] {
        [productBook, .json("/products/BTC-PERP-INTX", product), .json("/products", #"{"products":[\#(product)],"num_products":1}"#)]
    }

    // MARK: markets, book

    func marketsCase() throws -> ScriptedCase<[ExchangeClientMarket<CoinbaseClient.MarketName>]> {
        ScriptedCase(
            routes: Self.info,
            expected: [
                try makeMarket("BTC-PERP-INTX", base: "BTC", quote: "USDC", lotSize: amount("0.0001", "BTC"), minimumOrder: amount("0.0001", "BTC"), maxLeverage: 20, leverageSet: nil, isPerpetual: true),
            ]
        )
    }

    func bookCase() throws -> ScriptedCase<ExchangeClientBook<CoinbaseClient.MarketName>> {
        ScriptedCase(
            routes: Self.info,
            // READING: the volume is the day's in the base; 2^53 + 1, which no Double holds
            expected: makeBook("BTC-PERP-INTX", mid: try price("64250.5", "USDC"), bestBid: try price("64250.0", "USDC"), bestAsk: try price("64251.0", "USDC"), volume: try amount("9007199254740993", "BTC"), readAt: try iso("2024-09-22T10:13:20.123Z")),
            sent: ["BTC-PERP-INTX"]
        )
    }

    // MARK: orders: the order is created, then read back for what it filled

    private func order(id: String, created: String, status: String?, expected: OrderOutcome<CoinbaseClient.OrderId>, code: String? = nil) throws -> OrderCase<CoinbaseClient> {
        var routes = Self.info + [.json("order_configuration", created)]
        if let status {
            routes.append(.json("orders/historical/\(id)", status))
        }
        return OrderCase(
            side: .buy, size: try amount("0.0012", "BTC"), limit: try price("64300.5", "USDC"),
            routes: routes, expected: expected, expectedRefusalCode: code,
            sent: ["\"base_size\":\"0.0012\"", "\"limit_price\":\"64300.5\"", "ioc", "BUY", "BTC-PERP-INTX"]
        )
    }

    private static func created(_ id: String) -> String {
        #"{"success":true,"success_response":{"order_id":"\#(id)","product_id":"BTC-PERP-INTX","side":"BUY","client_order_id":"c-\#(id.prefix(4))"}}"#
    }

    private static func historical(_ id: String, status: String, filled: String, average: String) -> String {
        #"{"order":{"order_id":"\#(id)","product_id":"BTC-PERP-INTX","side":"BUY","status":"\#(status)","filled_size":"\#(filled)","average_filled_price":"\#(average)","last_fill_time":"2024-09-22T10:13:21.000Z","order_configuration":{"sor_limit_ioc":{"base_size":"0.0012","limit_price":"64300.5"}}}}"#
    }

    func filledOrder() throws -> OrderCase<CoinbaseClient> {
        let id = "c18f0c17-9971-40e6-8e5b-10df05d422f0"
        return try order(id: id, created: Self.created(id), status: Self.historical(id, status: "FILLED", filled: "0.0012", average: "64250.4"),
                         expected: .filled(units: try amount("0.0012", "BTC"), at: try price("64250.4", "USDC"), id: try Self.orderId(id)))
    }

    func partlyFilledOrder() throws -> OrderCase<CoinbaseClient> {
        // T60: the remainder of an immediate-or-cancel order is cancelled after 0.0006 filled
        let id = "0b7d1c55-2d5e-4c38-9a4e-3a3f0f6f1e01"
        return try order(id: id, created: Self.created(id), status: Self.historical(id, status: "CANCELLED", filled: "0.0006", average: "64250.4"),
                         expected: .partlyFilled(units: try amount("0.0006", "BTC"), at: try price("64250.4", "USDC"), id: try Self.orderId(id)))
    }

    func unmatchedOrder() throws -> OrderCase<CoinbaseClient> {
        // READING: Coinbase accepted the order, gave it an id, and cancelled it unfilled: cancelled, with its id
        let id = "3c4d5e6f-7a8b-4c9d-8e0f-1a2b3c4d5e6f"
        return try order(id: id, created: Self.created(id), status: Self.historical(id, status: "CANCELLED", filled: "0", average: "0"),
                         expected: .cancelled(id: try Self.orderId(id)))
    }

    func refusedOrder() throws -> OrderCase<CoinbaseClient> {
        try order(id: "none", created: #"{"success":false,"failure_reason":"UNKNOWN_FAILURE_REASON","error_response":{"error":"INSUFFICIENT_FUND","message":"Insufficient balance in source account","error_details":"","preview_failure_reason":"PREVIEW_INSUFFICIENT_FUND"}}"#,
                  status: nil, expected: .refused(text: "Insufficient balance in source account"), code: "INSUFFICIENT_FUND")
    }

    func quietOrderRoutes() throws -> (routes: [ScriptedRoute], orderNeedle: String) {
        (Self.info + [.unreachable("order_configuration")], "order_configuration")
    }

    func openOrdersCase() throws -> ScriptedCase<[ExchangeClientOpenOrder<CoinbaseClient.MarketName, CoinbaseClient.OrderId>]> {
        ScriptedCase(
            routes: Self.info + [.json("historical/batch", """
            {"orders":[{"order_id":"2ce038ae-c144-4de7-a0f1-82f7f4fca864","product_id":"BTC-PERP-INTX","side":"BUY","status":"OPEN",\
            "order_configuration":{"limit_limit_gtc":{"base_size":"0.002","limit_price":"60000.5"}},"filled_size":"0"}],"has_next":false,"cursor":""}
            """)],
            expected: [makeOpenOrder(try Self.orderId("2ce038ae-c144-4de7-a0f1-82f7f4fca864"), market: "BTC-PERP-INTX", side: .buy, units: try amount("0.002", "BTC"))],
            sent: ["OPEN"]
        )
    }

    func cancelCase() throws -> (id: CoinbaseClient.OrderId, scripted: ScriptedCase<Void>) {
        (try Self.orderId("2ce038ae-c144-4de7-a0f1-82f7f4fca864"),
         ScriptedCase(routes: Self.info + [.json("batch_cancel", #"{"results":[{"success":true,"failure_reason":"UNKNOWN_CANCEL_FAILURE_REASON","order_id":"2ce038ae-c144-4de7-a0f1-82f7f4fca864"}]}"#)],
                      expected: (), sent: ["2ce038ae-c144-4de7-a0f1-82f7f4fca864"]))
    }

    func cancelGoneCase() throws -> (id: CoinbaseClient.OrderId, error: ErrorCase) {
        // READING: the failure reason is the code and the only text
        (try Self.orderId("9f0e8d7c-6b5a-4f3e-8d2c-1b0a9f8e7d6c"),
         ErrorCase(routes: Self.info + [.json("batch_cancel", #"{"results":[{"success":false,"failure_reason":"UNKNOWN_CANCEL_ORDER","order_id":"9f0e8d7c-6b5a-4f3e-8d2c-1b0a9f8e7d6c"}]}"#)],
                   expected: .exchange(code: "UNKNOWN_CANCEL_ORDER", text: "UNKNOWN_CANCEL_ORDER"))) // INVENTED: ExchangeClientError.exchange(code:text:)
    }

    // MARK: account

    func accountStateCase() throws -> ScriptedCase<ExchangeClientAccountState<CoinbaseClient.MarketName>> {
        ScriptedCase(
            routes: Self.info + [
                .json("intx/portfolio", """
                {"portfolios":[{"portfolio_uuid":"\(Self.portfolio)","collateral":"1523.456789","position_notional":"642.506",\
                "margin_type":"MARGIN_TYPE_ISOLATED","unrealized_pnl":{"value":"-2.506","currency":"USDC"},\
                "total_balance":{"value":"1523.456789","currency":"USDC"}}],\
                "summary":{"collateral":"1523.456789","buying_power":{"value":"1200.5","currency":"USDC"},\
                "max_withdrawal_amount":{"value":"1200.5","currency":"USDC"}}}
                """),
                .json("intx/positions", """
                {"positions":[{"product_id":"BTC-PERP-INTX","symbol":"BTC-PERP-INTX","portfolio_uuid":"\(Self.portfolio)","net_size":"-0.01",\
                "entry_vwap":{"value":"64000.0","currency":"USDC"},"mark_price":{"value":"64250.6","currency":"USDC"},\
                "liquidation_price":{"value":"70123.4","currency":"USDC"},"position_side":"POSITION_SIDE_SHORT","margin_type":"MARGIN_TYPE_ISOLATED"}]}
                """),
            ],
            expected: makeAccountState(
                balance: try amount("1523.456789", "USDC"),
                withdrawable: try amount("1200.5", "USDC"),
                positions: [makePosition("BTC-PERP-INTX", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USDC"), mark: try price("64250.6", "USDC"), liquidationPrice: try price("70123.4", "USDC"))],
                // READING: the portfolio's margin type is the mode's name; cross is its alternative
                mode: makeMode("MARGIN_TYPE_ISOLATED", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: ["MARGIN_TYPE_CROSS"]),
                readAt: Date()
            ),
            sent: [Self.portfolio]
        )
    }

    // MARK: ledger

    private static func fill(_ entry: String, order: String, side: String, size: String, price: String, fee: String, time: String) -> String {
        #"{"entry_id":"\#(entry)","trade_id":"t-\#(entry)","order_id":"\#(order)","trade_time":"\#(time)","trade_type":"FILL","price":"\#(price)","size":"\#(size)","commission":"\#(fee)","product_id":"BTC-PERP-INTX","side":"\#(side)","liquidity_indicator":"TAKER"}"#
    }

    private static let fill1 = fill("e1", order: "c18f0c17-9971-40e6-8e5b-10df05d422f0", side: "BUY", size: "0.0012", price: "64250.4", fee: "0.023712", time: "2024-09-22T10:13:21.000Z")
    private static let fill2 = fill("e2", order: "5e9a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b", side: "SELL", size: "0.0005", price: "64260.0", fee: "0.009639", time: "2024-09-22T10:13:22.000Z")
    private static let fill3 = fill("e3", order: "7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", side: "BUY", size: "0.01", price: "70123.4", fee: "0.35", time: "2024-09-22T10:13:23.000Z")

    // ASSUMED SHAPE, least known: the international perpetuals' funding payments
    private static let funding = #"{"funding":[{"entry_id":"f1","product_id":"BTC-PERP-INTX","amount":{"value":"-0.0153","currency":"USDC"},"rate":"0.0000125","time":"2024-09-22T10:13:22.000Z"}],"cursor":""}"#

    func ledgerCase() throws -> LedgerCase<CoinbaseClient> {
        typealias Line = LedgerLine<CoinbaseClient.MarketName, CoinbaseClient.OrderId>
        let trade = Line.fill(market: "BTC-PERP-INTX", side: .buy, units: try amount("0.0012", "BTC"), price: try price("64250.4", "USDC"), fee: try amount("0.023712", "USDC"), order: try Self.orderId("c18f0c17-9971-40e6-8e5b-10df05d422f0"), closedBy: nil, time: try iso("2024-09-22T10:13:21.000Z"))
        let fundingLine = Line.funding(market: "BTC-PERP-INTX", amount: try amount("-0.0153", "USDC"), rate: try fraction("0.0000125"), time: try iso("2024-09-22T10:13:22.000Z"))
        let sameInstant = Line.fill(market: "BTC-PERP-INTX", side: .sell, units: try amount("0.0005", "BTC"), price: try price("64260.0", "USDC"), fee: try amount("0.009639", "USDC"), order: try Self.orderId("5e9a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b"), closedBy: nil, time: try iso("2024-09-22T10:13:22.000Z"))
        // READING: Coinbase's fill carries no reason the exchange closed it, so none is handed up
        let later = Line.fill(market: "BTC-PERP-INTX", side: .buy, units: try amount("0.01", "BTC"), price: try price("70123.4", "USDC"), fee: try amount("0.35", "USDC"), order: try Self.orderId("7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"), closedBy: nil, time: try iso("2024-09-22T10:13:23.000Z"))

        // the exchange answers newest first; the client hands up oldest first
        return LedgerCase(
            firstRoutes: [.json("historical/fills", #"{"fills":[\#(Self.fill1)],"cursor":""}"#), .json("funding", Self.funding)],
            firstExpected: [trade, fundingLine],
            resumeAfter: 1,
            resumeRoutes: [.json("historical/fills", #"{"fills":[\#(Self.fill3),\#(Self.fill2),\#(Self.fill1)],"cursor":""}"#), .json("funding", Self.funding)],
            resumeExpected: [sameInstant, later]
        )
    }

    // MARK: leverage, transfer, key

    func leverageCase() throws -> (leverage: Int, scripted: ScriptedCase<Void>) {
        // ASSUMED SHAPE, least known: the perpetuals' leverage setting
        (5, ScriptedCase(routes: Self.info + [.json("leverage", "{}")], expected: (), sent: ["BTC-PERP-INTX", "5", "ISOLATED"]))
    }

    func transferCase() throws -> (amount: Amount, from: String, to: String, scripted: ScriptedCase<Void>) {
        (try amount("500.25", "USDC"), Self.reserve, Self.portfolio,
         ScriptedCase(routes: Self.info + [.json("move_funds", #"{"source_portfolio_uuid":"\#(Self.reserve)","target_portfolio_uuid":"\#(Self.portfolio)"}"#)],
                      expected: (), sent: ["\"value\":\"500.25\"", "USDC", Self.reserve, Self.portfolio]))
    }

    func keyFactsCase() throws -> ScriptedCase<ExchangeClientKeyFacts> {
        // READING: Coinbase's can_transfer is the permission to send funds away, a withdrawal; moving between the account's
        // own portfolios rides on the trade permission. A key made to T103 has can_transfer false. No approver, no expiry.
        ScriptedCase(
            routes: [.json("key_permissions", #"{"can_view":true,"can_trade":true,"can_transfer":false,"portfolio_uuid":"\#(Self.portfolio)","portfolio_type":"INTX"}"#)],
            expected: makeKeyFacts(canTrade: true, canTransfer: true, canWithdraw: false, approvedBy: nil, validUntil: nil)
        )
    }

    // MARK: errors

    func rateLimitedCase() throws -> ErrorCase {
        ErrorCase(routes: [.json("", #"{"error":"rate_limit_exceeded","message":"Too many requests"}"#, status: 429, headers: ["Retry-After": "7"])],
                  expected: .rateLimited(retryAfter: .seconds(7))) // INVENTED: ExchangeClientError.rateLimited(retryAfter:)
    }

    func malformedBookCase() throws -> ErrorCase {
        ErrorCase(routes: [.json("product_book", #"{"pricebook":{"product_id":"BTC-PERP-INTX","bids":[{"price":"sixty-four thousand","size":"1.2"}],"asks":[{"price":"64251.0","size":"0.8"}],"time":"2024-09-22T10:13:20.123Z"}}"#),
                           .json("/products/BTC-PERP-INTX", Self.product), .json("/products", #"{"products":[\#(Self.product)],"num_products":1}"#)],
                  expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func ambiguousNumberBookCase() throws -> ErrorCase {
        ErrorCase(routes: [.json("product_book", #"{"pricebook":{"product_id":"BTC-PERP-INTX","bids":[{"price":"64,250.0","size":"1.2"}],"asks":[{"price":"64251.0","size":"0.8"}],"time":"2024-09-22T10:13:20.123Z"}}"#),
                           .json("/products/BTC-PERP-INTX", Self.product), .json("/products", #"{"products":[\#(Self.product)],"num_products":1}"#)],
                  expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func unauthorizedOrderCase() throws -> ErrorCase {
        ErrorCase(routes: Self.info + [.json("order_configuration", #"{"error":"unauthorized","message":"Unauthorized"}"#, status: 401)],
                  expected: .unauthorized) // INVENTED: ExchangeClientError.unauthorized
    }
}
