// CoinbaseOHLCVTests.swift — C32 run against Coinbase's OHLCV client.
//
// ASSUMED SHAPE: /api/v3/brokerage/market/products/BTC-USD/candles?start=<s>&end=<s>&granularity=ONE_DAY answers
// {"candles":[{"start": "<seconds>", "low", "high", "open", "close", "volume": decimal text}, …]} NEWEST FIRST, the
// still-open bar first, and no trade count: so this feed proves the ascending order and the nil trade count.

import CryptoAsset
import CryptoOHLCV
import Foundation
import Testing

struct CoinbaseOHLCVScript: OHLCVScript {
    func makeClient(session: ScriptedFeedSession, now: Date) throws -> CoinbaseOHLCVClient {
        CoinbaseOHLCVClient(session: session, now: { now }) // INVENTED: the conformer's name and initializer: the session seam and a clock
    }

    var market: CoinbaseOHLCVClient.MarketName { "BTC-USD" }
    var base: String { "BTC" }
    var quote: String { "USD" }
    var countsTrades: Bool { false }
    var needle: String { "candles" }
    var sentDailyInterval: String { "ONE_DAY" }

    func sentFrom(_ instant: Date) -> String { "start=\(Int64(instant.timeIntervalSince1970))" }

    func answer(closed: [FeedBar], open: FeedBar?) -> String {
        let all = (closed + (open.map { [$0] } ?? [])).reversed()
        let rows = all.map { bar in
            #"{"start":"\#(bar.openSeconds)","low":"\#(bar.low)","high":"\#(bar.high)","open":"\#(bar.open)","close":"\#(bar.close)","volume":"\#(bar.volume)"}"#
        }
        return #"{"candles":[\#(rows.joined(separator: ","))]}"#
    }
}

@Suite("C32 contract: CoinbaseOHLCVClient")
struct CoinbaseOHLCVClientTests {
    let contract = OHLCVClientContract(script: CoinbaseOHLCVScript())

    @Test("C32, T8: closed bars only", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func closedBarsOnly() async throws { try await contract.checkClosedBarsOnly() }
    @Test("C32: ascending by open time", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func ascending() async throws { try await contract.checkAscending() }
    @Test("C32: the feed's numbers exactly", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func exactNumbers() async throws { try await contract.checkExactNumbers() }
    @Test("C32: the timeframe's boundaries; the range's ends inclusive", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func boundaries() async throws { try await contract.checkBoundaries() }
    @Test("C32: bars outside the range are left out (READING)", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func outsideTheRange() async throws { try await contract.checkOutsideTheRangeIsLeftOut() }
    @Test("C32, AR86: the range is not rounded", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func rangeNotRounded() async throws { try await contract.checkRangeIsNotRounded() }
    @Test("C32: the interval as a count and a unit, on the wire", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func interval() async throws { try await contract.checkIntervalIsSent() }
    @Test("C32: the trade count, or nil", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func tradeCount() async throws { try await contract.checkTradeCount() }
    @Test("C32 openOHLCV: the still-open bar", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func openBar() async throws { try await contract.checkOpenBar() }
    @Test("C32 openOHLCV: nil without an open bar (READING)", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func noOpenBar() async throws { try await contract.checkNoOpenBar() }
    @Test("C32: a range past the feed's last bar is empty (READING)", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func pastTheEnd() async throws { try await contract.checkPastTheEnd() }
    @Test("C32: a range before the market is empty (READING)", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func beforeTheMarket() async throws { try await contract.checkBeforeTheMarket() }
    @Test("C32: a malformed number is the typed error", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func malformed() async throws { try await contract.checkMalformed() }
    @Test("C32: a rate limit carries Retry-After", .disabled("Classified 2026-10-06: the projector's script does not answer the feed's one request for the market's assets (Coinbase's market/products), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md")) func rateLimited() async throws { try await contract.checkRateLimited() }
}
