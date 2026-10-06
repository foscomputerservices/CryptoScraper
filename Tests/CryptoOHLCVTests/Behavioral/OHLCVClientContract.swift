// OHLCVClientContract.swift — C32's contract, written once, run against each feed's conformer.
//
// Projected from C32 and AR86 alone. Each feed's file supplies an `OHLCVScript`: how its wire writes the same five
// daily bars (four closed, one still open), and how its request writes a range and an interval.
//
// The bars, UTC: D0 2024-09-22, D1 2024-09-23, D2 2024-09-24, D3 2024-09-25 closed; D4 2024-09-26 still open.
// The client's clock stands at D4 + 12 hours.

import CryptoAsset
import CryptoOHLCV
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Synchronization
import Testing

// MARK: - Numbers, exactly

func amount(_ text: String, _ symbol: String) throws -> Amount {
    try Amount(parsing: text, of: Asset(symbol: symbol)) // INVENTED: CryptoAsset's exact text constructor for Amount and an asset by its symbol
}

func price(_ text: String, _ quote: String) throws -> Price {
    try Price(parsing: text, in: Asset(symbol: quote)) // INVENTED: CryptoAsset's exact text constructor for Price
}

// MARK: - The scripted session

struct ScriptedRoute: Sendable {
    let needle: String
    let status: Int
    let headers: [String: String]
    let body: Data

    static func json(_ needle: String, _ body: String, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) -> ScriptedRoute {
        ScriptedRoute(needle: needle, status: status, headers: headers, body: Data(body.utf8))
    }
}

final class ScriptedFeedSession: OHLCVClientSession, Sendable { // INVENTED: OHLCVClientSession, the URLSession-shaped seam a feed client takes as `session:` (AR31, AR86 name FOSFoundation's mockable session; the builder binds this double to it)
    let routes: [ScriptedRoute]
    private let kept = Mutex<[URLRequest]>([])

    init(_ routes: [ScriptedRoute]) {
        self.routes = routes
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) { // INVENTED: the seam's one requirement, URLSession's own shape
        kept.withLock { $0.append(request) }
        let matchable = Self.urlAndBody(of: request)
        guard let route = routes.first(where: { matchable.contains($0.needle) }) else {
            Issue.record("An unscripted request: \(matchable)")
            throw URLError(.unsupportedURL)
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: route.status, httpVersion: "HTTP/1.1", headerFields: route.headers)
        else { throw URLError(.badURL) }
        return (route.body, response)
    }

    var requests: [URLRequest] { kept.withLock { $0 } }

    var everythingSent: String { requests.map(Self.urlAndBody(of:)).joined(separator: "\n") }

    static func urlAndBody(of request: URLRequest) -> String {
        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        return "\(request.url?.absoluteString ?? "") \(body)"
    }
}

// MARK: - The bars, as text, the way every feed sends them

/// One daily bar as the feed's text has it
struct FeedBar: Sendable {
    let openSeconds: Int64
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String
    let trades: Int

    var openTime: Date { Date(timeIntervalSince1970: TimeInterval(openSeconds)) }
}

enum Bars {
    static let day: Int64 = 86_400
    static let d0 = FeedBar(openSeconds: 1_726_963_200, open: "63000.0", high: "64300.0", low: "62900.5", close: "64250.5", volume: "812.5", trades: 9876)
    // 2^53 + 1 as the volume: no Double holds it
    static let d1 = FeedBar(openSeconds: 1_727_049_600, open: "64250.5", high: "64900.0", low: "63800.1", close: "64500.0", volume: "9007199254740993", trades: 12345)
    static let d2 = FeedBar(openSeconds: 1_727_136_000, open: "64500.0", high: "65100.25", low: "64000.0", close: "64999.99", volume: "1234.56789", trades: 2345)
    static let d3 = FeedBar(openSeconds: 1_727_222_400, open: "64999.99", high: "65500.0", low: "64800.0", close: "65200.0", volume: "0.00000001", trades: 1)
    static let d4Open = FeedBar(openSeconds: 1_727_308_800, open: "65200.0", high: "65300.0", low: "65100.0", close: "65250.0", volume: "10.5", trades: 99)

    /// The client's clock: D4 + 12 hours
    static let now = Date(timeIntervalSince1970: 1_727_352_000)
}

/// A bar's values without its close time, which each feed states its own way and is asserted separately
struct BarValues: Hashable {
    let openTime: Date
    let open: Price
    let high: Price
    let low: Price
    let close: Price
    let volume: Amount
    let trades: Int?
    let isClosed: Bool

    init(_ bar: OHLCVClientBar) {
        openTime = bar.openTime
        open = bar.open
        high = bar.high
        low = bar.low
        close = bar.close
        volume = bar.volume
        trades = bar.trades
        isClosed = bar.isClosed
    }

    init(_ bar: FeedBar, quote: String, base: String, trades counted: Bool, isClosed: Bool) throws {
        openTime = bar.openTime
        open = try price(bar.open, quote)
        high = try price(bar.high, quote)
        low = try price(bar.low, quote)
        close = try price(bar.close, quote)
        volume = try amount(bar.volume, base)
        trades = counted ? bar.trades : nil
        self.isClosed = isClosed
    }
}

// MARK: - The script each feed supplies

protocol OHLCVScript: Sendable {
    associatedtype Client: OHLCVClient

    /// A fresh client over the scripted session, its clock standing at `now`
    func makeClient(session: ScriptedFeedSession, now: Date) throws -> Client

    var market: Client.MarketName { get }
    var base: String { get }
    var quote: String { get }
    /// Whether the feed sends a trade count
    var countsTrades: Bool { get }

    /// The feed's answer holding `closed` and, where given, the still-open bar, in the feed's own order and form
    func answer(closed: [FeedBar], open: FeedBar?) -> String
    /// The needle every candle request carries
    var needle: String { get }
    /// How the request writes an instant as the start of the range
    func sentFrom(_ instant: Date) -> String
    /// How the request writes one day
    var sentDailyInterval: String { get }
}

extension OHLCVScript {
    func routes(closed: [FeedBar], open: FeedBar?) -> [ScriptedRoute] {
        [.json(needle, answer(closed: closed, open: open))]
    }
}

// MARK: - The contract

struct OHLCVClientContract<Script: OHLCVScript> {
    let script: Script
    let daily = BarInterval(count: 1, unit: .day)

    private func client(_ routes: [ScriptedRoute]) throws -> (Script.Client, ScriptedFeedSession) {
        let session = ScriptedFeedSession(routes)
        return (try script.makeClient(session: session, now: Bars.now), session)
    }

    private func expected(_ bars: [FeedBar]) throws -> [BarValues] {
        try bars.map { try BarValues($0, quote: script.quote, base: script.base, trades: script.countsTrades, isClosed: true) }
    }

    /// C32, T8: closed bars only; the still-open bar the feed sent is not among them
    func checkClosedBarsOnly() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d1, Bars.d2, Bars.d3], open: Bars.d4Open))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.now)
        #expect(bars.allSatisfy(\.isClosed))
        #expect(!bars.contains { $0.openTime == Bars.d4Open.openTime })
        #expect(bars.map(BarValues.init) == (try expected([Bars.d1, Bars.d2, Bars.d3])))
    }

    /// C32: ascending by open time, whatever order the feed answered in
    func checkAscending() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d1, Bars.d2, Bars.d3], open: nil))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d3.openTime)
        #expect(bars.map(\.openTime) == [Bars.d1.openTime, Bars.d2.openTime, Bars.d3.openTime])
    }

    /// C32: every number is the feed's text exactly: 2^53 + 1, 1234.56789 and 0.00000001 survive
    func checkExactNumbers() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d1, Bars.d2, Bars.d3], open: nil))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d3.openTime)
        try #require(bars.count == 3)
        #expect(bars[0].volume == (try amount("9007199254740993", script.base)))
        #expect(bars[0].volume != (try amount("9007199254740992", script.base)))
        #expect(bars[1].volume == (try amount("1234.56789", script.base)))
        #expect(bars[1].high == (try price("65100.25", script.quote)))
        #expect(bars[1].close == (try price("64999.99", script.quote)))
        #expect(bars[2].volume == (try amount("0.00000001", script.base)))
    }

    /// C32: a bar's close lies after its open and no later than one interval on; the range's ends are inclusive
    func checkBoundaries() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d1, Bars.d2, Bars.d3], open: nil))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d3.openTime)
        for bar in bars {
            #expect(bar.closeTime > bar.openTime)
            #expect(bar.closeTime <= bar.openTime.addingTimeInterval(TimeInterval(Bars.day)))
        }
        // a bar opening at `from` and a bar opening at `through` are both in
        #expect(bars.first?.openTime == Bars.d1.openTime)
        #expect(bars.last?.openTime == Bars.d3.openTime)
    }

    /// C32 (READING: the client hands up only bars whose open lies within the range, whatever else the feed sent)
    func checkOutsideTheRangeIsLeftOut() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d0, Bars.d1, Bars.d2, Bars.d3], open: Bars.d4Open))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d2.openTime)
        #expect(bars.map(BarValues.init) == (try expected([Bars.d1, Bars.d2])))
    }

    /// C32, AR86: the range is not rounded: a start 37 seconds past midnight goes on the wire as given and is not refused
    func checkRangeIsNotRounded() async throws {
        let misaligned = Bars.d1.openTime.addingTimeInterval(37)
        let (client, session) = try client(script.routes(closed: [Bars.d2, Bars.d3], open: nil))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: misaligned, through: Bars.d3.openTime)
        #expect(session.everythingSent.contains(script.sentFrom(misaligned)))
        #expect(bars.map(\.openTime) == [Bars.d2.openTime, Bars.d3.openTime])
    }

    /// C32: the interval is a count and a unit, written the feed's way
    func checkIntervalIsSent() async throws {
        let (client, session) = try client(script.routes(closed: [Bars.d1], open: nil))
        _ = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d1.openTime)
        #expect(session.everythingSent.contains(script.sentDailyInterval))
    }

    /// C32: the trade count is the feed's when it sends one, and nil when it does not
    func checkTradeCount() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d1], open: nil))
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d1.openTime)
        try #require(bars.count == 1)
        #expect(bars[0].trades == (script.countsTrades ? 12345 : nil))
    }

    /// C32 openOHLCV: the still-open bar, its open time and its open price so far, never closed
    func checkOpenBar() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d3], open: Bars.d4Open))
        let open = try #require(try await client.openOHLCV(market: script.market, interval: daily))
        #expect(!open.isClosed)
        #expect(open.openTime == Bars.d4Open.openTime)
        #expect(open.open == (try price("65200.0", script.quote)))
    }

    /// C32 openOHLCV (READING: nil when the feed's answer holds no open bar)
    func checkNoOpenBar() async throws {
        let (client, _) = try client(script.routes(closed: [Bars.d3], open: nil))
        let open = try await client.openOHLCV(market: script.market, interval: daily)
        #expect(open == nil)
    }

    /// C32 (READING: a range past the feed's last bar is an empty answer, not an error)
    func checkPastTheEnd() async throws {
        let (client, _) = try client(script.routes(closed: [], open: nil))
        let from = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01, after the clock
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: from, through: from.addingTimeInterval(3 * 86_400))
        #expect(bars.isEmpty)
    }

    /// C32 (READING: a range before the market existed is an empty answer, not an error)
    func checkBeforeTheMarket() async throws {
        let (client, _) = try client(script.routes(closed: [], open: nil))
        let from = Date(timeIntervalSince1970: 1_230_768_000) // 2009-01-01
        let bars = try await client.ohlcv(market: script.market, interval: daily, from: from, through: from.addingTimeInterval(3 * 86_400))
        #expect(bars.isEmpty)
    }

    /// C32: a number that is not a number is the typed error, never a bar
    func checkMalformed() async throws {
        let broken = FeedBar(openSeconds: Bars.d1.openSeconds, open: "64,250.5", high: Bars.d1.high, low: Bars.d1.low, close: Bars.d1.close, volume: Bars.d1.volume, trades: Bars.d1.trades)
        let (client, _) = try client(script.routes(closed: [broken], open: nil))
        await #expect(throws: OHLCVClientError.malformedResponse) { // INVENTED: OHLCVClientError, the feed clients' typed errors (AR86 names the pattern, no type is declared)
            _ = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d1.openTime)
        }
    }

    /// C32: a rate limit is the typed limit error carrying Retry-After
    func checkRateLimited() async throws {
        let (client, _) = try client([.json(script.needle, "{}", status: 429, headers: ["Retry-After": "7"])])
        await #expect(throws: OHLCVClientError.rateLimited(retryAfter: .seconds(7))) { // INVENTED: OHLCVClientError.rateLimited(retryAfter:)
            _ = try await client.ohlcv(market: script.market, interval: daily, from: Bars.d1.openTime, through: Bars.d3.openTime)
        }
    }
}
