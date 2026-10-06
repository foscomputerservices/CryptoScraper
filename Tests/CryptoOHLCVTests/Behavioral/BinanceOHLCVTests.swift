// BinanceOHLCVTests.swift — C32 run against Binance's OHLCV client.
//
// ASSUMED SHAPE: /api/v3/klines answers an array of 12-element arrays [openTime ms, "open", "high", "low", "close",
// "volume", closeTime ms, "quoteVolume", trades, "takerBuyBase", "takerBuyQuote", "ignore"], ascending, the open bar last.

import CryptoAsset
import CryptoOHLCV
import Foundation
import Testing

struct BinanceOHLCVScript: OHLCVScript {
    func makeClient(session: ScriptedFeedSession, now: Date) throws -> BinanceOHLCVClient {
        BinanceOHLCVClient(session: session, now: { now }) // INVENTED: the conformer's name and initializer: the session seam and a clock that decides which bar is still open
    }

    var market: BinanceOHLCVClient.MarketName { "BTCUSDT" }
    var base: String { "BTC" }
    var quote: String { "USDT" }
    var countsTrades: Bool { true }
    var needle: String { "klines" }
    var sentDailyInterval: String { "interval=1d" }

    func sentFrom(_ instant: Date) -> String { "startTime=\(Int64(instant.timeIntervalSince1970 * 1000))" }

    func answer(closed: [FeedBar], open: FeedBar?) -> String {
        let rows = (closed + (open.map { [$0] } ?? [])).map { bar in
            let ms = bar.openSeconds * 1000
            return #"[\#(ms),"\#(bar.open)","\#(bar.high)","\#(bar.low)","\#(bar.close)","\#(bar.volume)",\#(ms + 86_399_999),"0",\#(bar.trades),"0","0","0"]"#
        }
        return "[\(rows.joined(separator: ","))]"
    }
}

@Suite("C32 contract: BinanceOHLCVClient")
struct BinanceOHLCVClientTests {
    let contract = OHLCVClientContract(script: BinanceOHLCVScript())

    @Test("C32, T8: closed bars only") func closedBarsOnly() async throws { try await contract.checkClosedBarsOnly() }
    @Test("C32: ascending by open time") func ascending() async throws { try await contract.checkAscending() }
    @Test("C32: the feed's numbers exactly") func exactNumbers() async throws { try await contract.checkExactNumbers() }
    @Test("C32: the timeframe's boundaries; the range's ends inclusive") func boundaries() async throws { try await contract.checkBoundaries() }
    @Test("C32: bars outside the range are left out (READING)") func outsideTheRange() async throws { try await contract.checkOutsideTheRangeIsLeftOut() }
    @Test("C32, AR86: the range is not rounded") func rangeNotRounded() async throws { try await contract.checkRangeIsNotRounded() }
    @Test("C32: the interval as a count and a unit, on the wire") func interval() async throws { try await contract.checkIntervalIsSent() }
    @Test("C32: the trade count, or nil") func tradeCount() async throws { try await contract.checkTradeCount() }
    @Test("C32 openOHLCV: the still-open bar") func openBar() async throws { try await contract.checkOpenBar() }
    @Test("C32 openOHLCV: nil without an open bar (READING)") func noOpenBar() async throws { try await contract.checkNoOpenBar() }
    @Test("C32: a range past the feed's last bar is empty (READING)") func pastTheEnd() async throws { try await contract.checkPastTheEnd() }
    @Test("C32: a range before the market is empty (READING)") func beforeTheMarket() async throws { try await contract.checkBeforeTheMarket() }
    @Test("C32: a malformed number is the typed error") func malformed() async throws { try await contract.checkMalformed() }
    @Test("C32: a rate limit carries Retry-After") func rateLimited() async throws { try await contract.checkRateLimited() }
}
