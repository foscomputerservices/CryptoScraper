// HyperliquidScript.swift — Hyperliquid's wire, scripted for C31's contract.
//
// ASSUMED SHAPE, every body in this file: written from the public shape of Hyperliquid's /info and /exchange
// APIs as known without a recording (no web, no POC opened). The builder replaces a body with a recorded one
// where they differ and keeps the expected value; an assertion never changes.
//
// The test key is the private key 1, whose address is 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf:
// a throwaway, bound to no account. Never the POC's agent key (T40).

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import Foundation
import Testing

struct HyperliquidScript: ExchangeClientScript {
    typealias Client = HyperliquidClient

    static let agentKeyHex = "0x0000000000000000000000000000000000000000000000000000000000000001"
    static let agentAddress = "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"
    static let mainWallet = "0x2222222222222222222222222222222222222222"
    static let subAccount = "0x1111111111111111111111111111111111111111"

    func makeClient(session: ScriptedSession, log: LogCapture) throws -> HyperliquidClient {
        try HyperliquidClient(credential: .agentKey(HyperliquidAgentKey(hex: Self.agentKeyHex)), endpoint: .testMarket, session: session, log: { log.record($0) }) // INVENTED: HyperliquidAgentKey(hex:), the `log:` parameter; the rest is C31's own example
    }

    var secretTexts: [String] { ["0000000000000000000000000000000000000000000000000000000000000001"] }
    var keyIdentifierTexts: [String] { [] }
    var market: HyperliquidClient.MarketName { "BTC" }
    var account: String { Self.subAccount }

    // MARK: The info routes every call may need (the asset index, the mids, the contexts)

    static let meta = ScriptedRoute.json("\"meta\"", """
    {"universe":[{"name":"BTC","szDecimals":5,"maxLeverage":40},{"name":"ETH","szDecimals":4,"maxLeverage":25}]}
    """)

    static let metaAndAssetCtxs = ScriptedRoute.json("metaAndAssetCtxs", """
    [{"universe":[{"name":"BTC","szDecimals":5,"maxLeverage":40},{"name":"ETH","szDecimals":4,"maxLeverage":25}]},\
    [{"funding":"0.0000125","openInterest":"1234.5","prevDayPx":"63000.0","dayNtlVlm":"9007199254740993","premium":"0.0001",\
    "oraclePx":"64249.0","markPx":"64250.6","midPx":"64250.5","impactPxs":["64250.0","64251.0"],"dayBaseVlm":"140.2"},\
    {"funding":"0.00001","openInterest":"9876.5","prevDayPx":"3000.0","dayNtlVlm":"123456.7","premium":"0.0","oraclePx":"3100.0",\
    "markPx":"3100.3","midPx":"3100.25","impactPxs":["3100.0","3100.5"],"dayBaseVlm":"40.1"}]]
    """)

    static let allMids = ScriptedRoute.json("allMids", """
    {"BTC":"64250.5","ETH":"3100.25"}
    """)

    static let l2Book = ScriptedRoute.json("l2Book", """
    {"coin":"BTC","time":1727000000123,"levels":[[{"px":"64250.0","sz":"1.2","n":3},{"px":"64249.5","sz":"2.0","n":1}],\
    [{"px":"64251.0","sz":"0.8","n":2},{"px":"64252.0","sz":"3.1","n":4}]]}
    """)

    static var info: [ScriptedRoute] { [metaAndAssetCtxs, meta, allMids, l2Book] }

    static func exchangeOK(_ needle: String, _ body: String) -> ScriptedRoute { .json(needle, body) }

    // MARK: markets, book

    func marketsCase() throws -> ScriptedCase<[ExchangeClientMarket<HyperliquidClient.MarketName>]> {
        ScriptedCase(
            routes: Self.info,
            expected: [
                // READING: Hyperliquid's minimum is ten dollars of value, an amount of the quote
                try makeMarket("BTC", base: "BTC", quote: "USDC", lotSize: amount("0.00001", "BTC"), minimumOrder: amount("10", "USDC"), maxLeverage: 40, leverageSet: nil, isPerpetual: true),
                try makeMarket("ETH", base: "ETH", quote: "USDC", lotSize: amount("0.0001", "ETH"), minimumOrder: amount("10", "USDC"), maxLeverage: 25, leverageSet: nil, isPerpetual: true),
            ]
        )
    }

    func bookCase() throws -> ScriptedCase<ExchangeClientBook<HyperliquidClient.MarketName>> {
        ScriptedCase(
            routes: Self.info,
            // READING: the volume is the day's notional, an amount of the quote; 2^53 + 1, which no Double holds
            expected: makeBook("BTC", mid: try price("64250.5", "USDC"), bestBid: try price("64250.0", "USDC"), bestAsk: try price("64251.0", "USDC"), volume: try amount("9007199254740993", "USDC"), readAt: ms(1_727_000_000_123)),
            sent: ["\"BTC\""]
        )
    }

    // MARK: orders

    private func order(_ statuses: String, expected: OrderOutcome<HyperliquidClient.OrderId>) throws -> OrderCase<HyperliquidClient> {
        OrderCase(
            side: .buy, size: try amount("0.00123", "BTC"), limit: try price("64300.5", "USDC"),
            routes: Self.info + [Self.exchangeOK("\"order\"", """
            {"status":"ok","response":{"type":"order","data":{"statuses":[\(statuses)]}}}
            """)],
            expected: expected,
            // the size and limit as exact text, the time in force, the sub-account as the vault
            sent: ["\"0.00123\"", "\"64300.5\"", "Ioc", Self.subAccount]
        )
    }

    func filledOrder() throws -> OrderCase<HyperliquidClient> {
        try order(#"{"filled":{"totalSz":"0.00123","avgPx":"64250.4","oid":77738308}}"#,
                  expected: .filled(units: try amount("0.00123", "BTC"), at: try price("64250.4", "USDC"), id: try decoded(HyperliquidClient.OrderId.self, json: "77738308")))
    }

    func partlyFilledOrder() throws -> OrderCase<HyperliquidClient> {
        // T60: the exchange filled 0.0006 of the 0.00123 asked
        try order(#"{"filled":{"totalSz":"0.0006","avgPx":"64250.4","oid":77738309}}"#,
                  expected: .partlyFilled(units: try amount("0.0006", "BTC"), at: try price("64250.4", "USDC"), id: try decoded(HyperliquidClient.OrderId.self, json: "77738309")))
    }

    func unmatchedOrder() throws -> OrderCase<HyperliquidClient> {
        // READING: an immediate-or-cancel order that met nothing never rested and has no id: cancelled before accepted
        try order(#"{"error":"Order could not immediately match against any resting orders. asset=0"}"#,
                  expected: .cancelledBeforeAccepted)
    }

    func refusedOrder() throws -> OrderCase<HyperliquidClient> {
        // READING: Hyperliquid sends no code with a refusal; the code is left unasserted
        try order(#"{"error":"Order must have minimum value of $10."}"#,
                  expected: .refused(text: "Order must have minimum value of $10."))
    }

    func quietOrderRoutes() throws -> (routes: [ScriptedRoute], orderNeedle: String) {
        (Self.info + [.unreachable("\"order\"")], "\"order\"")
    }

    func openOrdersCase() throws -> ScriptedCase<[ExchangeClientOpenOrder<HyperliquidClient.MarketName, HyperliquidClient.OrderId>]> {
        ScriptedCase(
            routes: Self.info + [.json("openOrders", """
            [{"coin":"BTC","side":"B","limitPx":"60000.5","sz":"0.002","oid":77738310,"timestamp":1727000000999,"origSz":"0.002"}]
            """)],
            expected: [makeOpenOrder(try decoded(HyperliquidClient.OrderId.self, json: "77738310"), market: "BTC", side: .buy, units: try amount("0.002", "BTC"))],
            sent: [Self.subAccount]
        )
    }

    func cancelCase() throws -> (id: HyperliquidClient.OrderId, scripted: ScriptedCase<Void>) {
        (try decoded(HyperliquidClient.OrderId.self, json: "77738310"),
         ScriptedCase(routes: Self.info + [Self.exchangeOK("\"cancel\"", """
         {"status":"ok","response":{"type":"cancel","data":{"statuses":["success"]}}}
         """)], expected: (), sent: ["77738310"]))
    }

    func cancelGoneCase() throws -> (id: HyperliquidClient.OrderId, error: ErrorCase) {
        // READING: Hyperliquid's refusal of a cancel is the exchange's typed error with its text and no code
        (try decoded(HyperliquidClient.OrderId.self, json: "77738311"),
         ErrorCase(routes: Self.info + [Self.exchangeOK("\"cancel\"", """
         {"status":"ok","response":{"type":"cancel","data":{"statuses":[{"error":"Order was never placed, already canceled, or filled."}]}}}
         """)], expected: .exchange(code: nil, text: "Order was never placed, already canceled, or filled."))) // INVENTED: ExchangeClientError.exchange(code:text:)
    }

    // MARK: account

    func accountStateCase() throws -> ScriptedCase<ExchangeClientAccountState<HyperliquidClient.MarketName>> {
        ScriptedCase(
            routes: Self.info + [
                .json("clearinghouseState", """
                {"marginSummary":{"accountValue":"1523.456789","totalNtlPos":"642.506","totalRawUsd":"2165.962789","totalMarginUsed":"128.5"},\
                "crossMarginSummary":{"accountValue":"1523.456789","totalNtlPos":"0.0","totalRawUsd":"1523.456789","totalMarginUsed":"0.0"},\
                "withdrawable":"1200.5","assetPositions":[{"type":"oneWay","position":{"coin":"BTC","szi":"-0.01",\
                "leverage":{"type":"isolated","value":5,"rawUsd":"770.0"},"entryPx":"64000.0","positionValue":"642.506",\
                "unrealizedPnl":"-2.506","returnOnEquity":"-0.019","liquidationPx":"70123.4","marginUsed":"128.5","maxLeverage":40,\
                "cumFunding":{"allTime":"0.5","sinceOpen":"0.1","sinceChange":"0.1"}}}],"time":1727000000456}
                """),
                // ASSUMED SHAPE and a READING: the account's mode read from the exchange by name
                .json("userAbstraction", "\"default\""),
            ],
            expected: makeAccountState(
                balance: try amount("1523.456789", "USDC"),
                withdrawable: try amount("1200.5", "USDC"),
                // a negative size is a short; the units are the size's magnitude; the mark is the exchange's
                positions: [makePosition("BTC", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USDC"), mark: try price("64250.6", "USDC"), liquidationPrice: try price("70123.4", "USDC"))],
                mode: makeMode("default", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: ["unifiedAccount", "portfolioMargin"]),
                readAt: ms(1_727_000_000_456)
            ),
            sent: [Self.subAccount]
        )
    }

    // MARK: ledger

    private static func fill(tid: Int, oid: Int, time: Int64, side: String, px: String, sz: String, fee: String, dir: String, liquidation: Bool = false) -> String {
        let liquidated = liquidation ? #","liquidation":{"liquidatedUser":"\#(subAccount)","markPx":"\#(px)","method":"market"}"# : ""
        return #"{"coin":"BTC","px":"\#(px)","sz":"\#(sz)","side":"\#(side)","time":\#(time),"startPosition":"0.0","dir":"\#(dir)","closedPnl":"0.0","hash":"0x\#(String(repeating: "a", count: 63))\#(tid % 10)","oid":\#(oid),"crossed":true,"fee":"\#(fee)","tid":\#(tid),"feeToken":"USDC"\#(liquidated)}"#
    }

    private static let firstFills = "[\(fill(tid: 111, oid: 77738308, time: 1727000001000, side: "B", px: "64250.4", sz: "0.00123", fee: "0.023712", dir: "Open Long"))]"

    private static let funding = """
    [{"time":1727000002000,"hash":"0x0000000000000000000000000000000000000000000000000000000000000000",\
    "delta":{"type":"funding","coin":"BTC","usdc":"-0.0153","szi":"-0.01","fundingRate":"0.0000125"}}]
    """

    private static let firstNonFunding = """
    [{"time":1727000000500,"hash":"0x0000000000000000000000000000000000000000000000000000000000000001","delta":{"type":"deposit","usdc":"1000.0"}},\
    {"time":1727000000700,"hash":"0x0000000000000000000000000000000000000000000000000000000000000002",\
    "delta":{"type":"subAccountTransfer","usdc":"500.25","user":"\(mainWallet)","destination":"\(subAccount)"}},\
    {"time":1727000002500,"hash":"0x0000000000000000000000000000000000000000000000000000000000000003",\
    "delta":{"type":"withdraw","usdc":"100.0","nonce":1727000002400,"fee":"1.0"}}]
    """

    private static let resumedFills = "[\(fill(tid: 112, oid: 77738311, time: 1727000002000, side: "A", px: "64260.0", sz: "0.0005", fee: "0.009639", dir: "Close Long")),\(fill(tid: 113, oid: 77738400, time: 1727000003000, side: "B", px: "70123.4", sz: "0.01", fee: "0.35", dir: "Close Short", liquidation: true))]"

    private static let resumedNonFunding = """
    [{"time":1727000002500,"hash":"0x0000000000000000000000000000000000000000000000000000000000000003",\
    "delta":{"type":"withdraw","usdc":"100.0","nonce":1727000002400,"fee":"1.0"}}]
    """

    func ledgerCase() throws -> LedgerCase<HyperliquidClient> {
        let oid = { (text: String) throws -> HyperliquidClient.OrderId in try decoded(HyperliquidClient.OrderId.self, json: text) }
        let deposit = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.deposit(try amount("1000.0", "USDC"), time: ms(1_727_000_000_500))
        let move = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.internalMove(try amount("500.25", "USDC"), from: Self.mainWallet, to: Self.subAccount, time: ms(1_727_000_000_700))
        let firstFill = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.fill(market: "BTC", side: .buy, units: try amount("0.00123", "BTC"), price: try price("64250.4", "USDC"), fee: try amount("0.023712", "USDC"), order: try oid("77738308"), closedBy: nil, time: ms(1_727_000_001_000))
        let fundingLine = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.funding(market: "BTC", amount: try amount("-0.0153", "USDC"), rate: try fraction("0.0000125"), time: ms(1_727_000_002_000))
        let withdrawal = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.withdrawal(try amount("100.0", "USDC"), time: ms(1_727_000_002_500))
        let sameInstantFill = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.fill(market: "BTC", side: .sell, units: try amount("0.0005", "BTC"), price: try price("64260.0", "USDC"), fee: try amount("0.009639", "USDC"), order: try oid("77738311"), closedBy: nil, time: ms(1_727_000_002_000))
        let liquidation = LedgerLine<HyperliquidClient.MarketName, HyperliquidClient.OrderId>.fill(market: "BTC", side: .buy, units: try amount("0.01", "BTC"), price: try price("70123.4", "USDC"), fee: try amount("0.35", "USDC"), order: try oid("77738400"), closedBy: .liquidation, time: ms(1_727_000_003_000))

        return LedgerCase(
            firstRoutes: [.json("userFillsByTime", Self.firstFills), .json("userFunding", Self.funding), .json("userNonFundingLedgerUpdates", Self.firstNonFunding)],
            firstExpected: [deposit, move, firstFill, fundingLine, withdrawal],
            // resumed after the funding at …2000: the exchange answers from that millisecond on, repeating the funding
            // and the withdrawal it already gave; the fill at the same millisecond is unseen and must come back
            resumeAfter: 3,
            resumeRoutes: [.json("userFillsByTime", Self.resumedFills), .json("userFunding", Self.funding), .json("userNonFundingLedgerUpdates", Self.resumedNonFunding)],
            // READING: the withdrawal at …2500 lies after the cursor and comes back once
            resumeExpected: [sameInstantFill, withdrawal, liquidation],
            resumeSent: ["1727000002000"]
        )
    }

    // MARK: leverage, transfer, key

    func leverageCase() throws -> (leverage: Int, scripted: ScriptedCase<Void>) {
        (5, ScriptedCase(routes: Self.info + [Self.exchangeOK("updateLeverage", #"{"status":"ok","response":{"type":"default"}}"#)],
                         expected: (), sent: ["updateLeverage", "\"isCross\":false", "\"leverage\":5", Self.subAccount]))
    }

    func transferCase() throws -> (amount: Amount, from: String, to: String, scripted: ScriptedCase<Void>) {
        // ASSUMED SHAPE: a sub-account transfer carries the dollars in millionths as an integer
        (try amount("500.25", "USDC"), Self.mainWallet, Self.subAccount,
         ScriptedCase(routes: Self.info + [Self.exchangeOK("subAccountTransfer", #"{"status":"ok","response":{"type":"default"}}"#)],
                      expected: (), sent: ["subAccountTransfer", "500250000", Self.subAccount]))
    }

    func keyFactsCase() throws -> ScriptedCase<ExchangeClientKeyFacts> {
        ScriptedCase(
            routes: [
                .json("userRole", #"{"role":"agent","data":{"user":"\#(Self.mainWallet)"}}"#),
                .json("extraAgents", #"[{"address":"\#(Self.agentAddress)","name":"fosline","validUntil":1767225600000}]"#),
            ],
            // AR33: the agent trades and moves between sub-accounts; it cannot withdraw
            expected: makeKeyFacts(canTrade: true, canTransfer: true, canWithdraw: false, approvedBy: Self.mainWallet, validUntil: ms(1_767_225_600_000)),
            sent: [Self.agentAddress]
        )
    }

    // MARK: errors

    func rateLimitedCase() throws -> ErrorCase {
        ErrorCase(routes: [.json("", "{}", status: 429, headers: ["Retry-After": "7"])],
                  expected: .rateLimited(retryAfter: .seconds(7))) // INVENTED: ExchangeClientError.rateLimited(retryAfter:)
    }

    func malformedBookCase() throws -> ErrorCase {
        ErrorCase(routes: [Self.metaAndAssetCtxs, Self.meta, Self.allMids, .json("l2Book", """
        {"coin":"BTC","time":1727000000123,"levels":[[{"px":"sixty-four thousand","sz":"1.2","n":3}],[{"px":"64251.0","sz":"0.8","n":2}]]}
        """)], expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func ambiguousNumberBookCase() throws -> ErrorCase {
        ErrorCase(routes: [Self.metaAndAssetCtxs, Self.meta, Self.allMids, .json("l2Book", """
        {"coin":"BTC","time":1727000000123,"levels":[[{"px":"64,250.0","sz":"1.2","n":3}],[{"px":"64251.0","sz":"0.8","n":2}]]}
        """)], expected: .malformedResponse) // INVENTED: ExchangeClientError.malformedResponse
    }

    func unauthorizedOrderCase() throws -> ErrorCase {
        // READING: an agent the main wallet no longer approves is answered so; it is the unauthorized error
        ErrorCase(routes: Self.info + [Self.exchangeOK("\"order\"", #"{"status":"err","response":"User or API Wallet \#(Self.agentAddress) does not exist."}"#)],
                  expected: .unauthorized) // INVENTED: ExchangeClientError.unauthorized
    }
}
