// KrakenOHLCVTests.swift — C32 run against Kraken's OHLCV client.
//
// ASSUMED SHAPE: /0/public/OHLC?pair=XBTUSD&interval=1440&since=<seconds> answers
// {"error":[],"result":{"XXBTZUSD":[[time s, "open", "high", "low", "close", "vwap", "volume", count], …],"last":<seconds>}},
// ascending, the still-open bar last. READING: which bar is still open is decided by the client's clock.

import CryptoAsset
import CryptoOHLCV
import Foundation
import Testing

struct KrakenOHLCVScript: OHLCVScript {
    func makeClient(session: ScriptedFeedSession, now: Date) throws -> KrakenOHLCVClient {
        KrakenOHLCVClient(session: session, now: { now }) // INVENTED: the conformer's name and initializer: the session seam and a clock
    }

    var market: KrakenOHLCVClient.MarketName { "XBTUSD" }
    var base: String { "BTC" }
    var quote: String { "USD" }
    var countsTrades: Bool { true }
    var needle: String { "OHLC" }
    var sentDailyInterval: String { "interval=1440" }

    func sentFrom(_ instant: Date) -> String { "since=\(Int64(instant.timeIntervalSince1970))" }

    func answer(closed: [FeedBar], open: FeedBar?) -> String {
        let all = closed + (open.map { [$0] } ?? [])
        let rows = all.map { bar in
            #"[\#(bar.openSeconds),"\#(bar.open)","\#(bar.high)","\#(bar.low)","\#(bar.close)","\#(bar.close)","\#(bar.volume)",\#(bar.trades)]"#
        }
        let last = closed.last?.openSeconds ?? 0
        return #"{"error":[],"result":{"XXBTZUSD":[\#(rows.joined(separator: ","))],"last":\#(last)}}"#
    }
}

@Suite("C32 contract: KrakenOHLCVClient")
struct KrakenOHLCVClientTests {
    let contract = OHLCVClientContract(script: KrakenOHLCVScript())

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
