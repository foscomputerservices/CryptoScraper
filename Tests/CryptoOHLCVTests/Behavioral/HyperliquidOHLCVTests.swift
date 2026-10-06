// HyperliquidOHLCVTests.swift — C32 run against Hyperliquid's OHLCV client.
//
// ASSUMED SHAPE: /info {"type":"candleSnapshot","req":{"coin","interval","startTime","endTime"}} answers
// [{"t": open ms, "T": close ms, "s": coin, "i": interval, "o", "c", "h", "l", "v": decimal text, "n": trades}], ascending.

import CryptoAsset
import CryptoOHLCV
import Foundation
import Testing

struct HyperliquidOHLCVScript: OHLCVScript {
    func makeClient(session: ScriptedFeedSession, now: Date) throws -> HyperliquidOHLCVClient {
        HyperliquidOHLCVClient(session: session, now: { now }) // INVENTED: the conformer's name and initializer: the session seam and a clock
    }

    var market: HyperliquidOHLCVClient.MarketName { "BTC" }
    var base: String { "BTC" }
    var quote: String { "USDC" }
    var countsTrades: Bool { true }
    var needle: String { "candleSnapshot" }
    var sentDailyInterval: String { "\"interval\":\"1d\"" }

    func sentFrom(_ instant: Date) -> String { "\"startTime\":\(Int64(instant.timeIntervalSince1970 * 1000))" }

    func answer(closed: [FeedBar], open: FeedBar?) -> String {
        let rows = (closed + (open.map { [$0] } ?? [])).map { bar in
            let ms = bar.openSeconds * 1000
            return #"{"t":\#(ms),"T":\#(ms + 86_399_999),"s":"BTC","i":"1d","o":"\#(bar.open)","c":"\#(bar.close)","h":"\#(bar.high)","l":"\#(bar.low)","v":"\#(bar.volume)","n":\#(bar.trades)}"#
        }
        return "[\(rows.joined(separator: ","))]"
    }
}

@Suite("C32 contract: HyperliquidOHLCVClient")
struct HyperliquidOHLCVClientTests {
    let contract = OHLCVClientContract(script: HyperliquidOHLCVScript())

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
