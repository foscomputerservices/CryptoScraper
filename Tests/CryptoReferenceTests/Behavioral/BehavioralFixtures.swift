// BehavioralFixtures.swift — the test-owned doubles, helpers and recorded-response fixtures of layer A's behavioral suite
//
// Everything in this file belongs to the tests. The adapter functions it calls (`behavioralBinanceClient`,
// `behavioralBinanceMarket`, `behavioralCoinMarketCapClient`, `behavioralExchangeError`, `behavioralLimit`) are the
// builder's, one per invented signature, under THE WIRING RULE (see BehavioralAssumptions.md).
//
// No fixture here was recorded: there was no network. Each was written from the public shape of the API as known,
// and every one is marked `// ASSUMED SHAPE`.

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

// MARK: - The mocked session

/// The one session the tests speak to; the adapter binds it to FOSFoundation's mockable session
protocol BehavioralSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// A response the tests script: a status, a body and its headers
struct RecordedResponse: Sendable {
    let status: Int
    let body: String
    let headers: [String: String]

    init(status: Int = 200, body: String, headers: [String: String] = ["Content-Type": "application/json"]) {
        self.status = status
        self.body = body
        self.headers = headers
    }
}

/// Answers the scripted responses in order, repeating the last, and records every request
actor RecordedSession: BehavioralSession {
    private let responses: [RecordedResponse]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [RecordedResponse]) {
        self.responses = responses
    }

    init(_ body: String, status: Int = 200) {
        self.responses = [RecordedResponse(status: status, body: body)]
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = min(requests.count, responses.count - 1)
        requests.append(request)
        let response = responses[index]
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
                                   headerFields: response.headers)!
        return (Data(response.body.utf8), http)
    }

    var queries: [[String: String]] { requests.map(queryItems(of:)) }
}

/// The query items of a request, by name
func queryItems(of request: URLRequest) -> [String: String] {
    guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
    var items: [String: String] = [:]
    for item in components.queryItems ?? [] { items[item.name] = item.value ?? "" }
    return items
}

/// A Binance `/api/v3/klines` endpoint over a synthetic series: honours `symbol`, `interval`, `startTime`, `endTime` and
/// `limit` as Binance documents them, leaves out the bars named missing, never serves a bar that has not begun at
/// `nowMs`, and answers HTTP 429 on the request indices it is told to limit
// ASSUMED SHAPE: Binance's paging semantics — bars with openTime >= startTime and <= endTime, ascending, at most
// `limit` (default 500, at most 1000); without startTime, the latest `limit` bars, the still-open one last.
actor BehavioralBinanceFeed: BehavioralSession {
    let firstOpenMs: Int64
    let intervalMs: Int64
    let count: Int
    let missing: Set<Int>
    let nowMs: Int64
    /// Request index → the `Retry-After` header text to send with a 429, or nil to send a 429 without one
    private let limited: [Int: String?]
    private(set) var requests: [URLRequest] = []

    init(firstOpenMs: Int64, intervalMs: Int64, count: Int, missing: Set<Int> = [], nowMs: Int64,
         limited: [Int: String?] = [:]) {
        self.firstOpenMs = firstOpenMs
        self.intervalMs = intervalMs
        self.count = count
        self.missing = missing
        self.nowMs = nowMs
        self.limited = limited
    }

    var queries: [[String: String]] { requests.map(queryItems(of:)) }

    /// The open times of every bar this feed holds, the open one included, in order
    nonisolated var servedOpenTimes: [Int64] {
        (0..<count).filter { !missing.contains($0) }
            .map { firstOpenMs + Int64($0) * intervalMs }
            .filter { $0 <= nowMs }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = requests.count
        requests.append(request)
        let url = request.url!

        if let retryAfter = limited[index] {
            var headers = ["Content-Type": "application/json"]
            if let retryAfter { headers["Retry-After"] = retryAfter }
            // ASSUMED SHAPE: the body Binance sends with a 429
            let body = #"{"code":-1003,"msg":"Too much request weight used; current limit is 6000 request weight per 1 MINUTE. Please use WebSocket Streams for live updates to avoid polling the API."}"#
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 429, httpVersion: "HTTP/1.1", headerFields: headers)!)
        }

        let query = queryItems(of: request)
        let limit = min(Int(query["limit"] ?? "") ?? 500, 1000)
        var openTimes = servedOpenTimes
        if let start = query["startTime"].flatMap({ Int64($0) }) {
            openTimes = openTimes.filter { $0 >= start }
            if let end = query["endTime"].flatMap({ Int64($0) }) { openTimes = openTimes.filter { $0 <= end } }
            openTimes = Array(openTimes.prefix(limit))
        } else {
            if let end = query["endTime"].flatMap({ Int64($0) }) { openTimes = openTimes.filter { $0 <= end } }
            openTimes = Array(openTimes.suffix(limit))
        }
        let body = "[" + openTimes.map { syntheticKline(openMs: $0, index: Int(($0 - firstOpenMs) / intervalMs), intervalMs: intervalMs) }
            .joined(separator: ",") + "]"
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                                  headerFields: ["Content-Type": "application/json"])!)
    }
}

/// One synthetic kline: open "1000+i.00", high "…50", low "999+i.75", close "1000+i.25", volume "1.00000000", 10 trades
// ASSUMED SHAPE: the 12-element kline array of Binance's public documentation
func syntheticKline(openMs: Int64, index: Int, intervalMs: Int64) -> String {
    let n = 1000 + index
    return #"[\#(openMs),"\#(n).00","\#(n).50","\#(n - 1).75","\#(n).25","1.00000000",\#(openMs + intervalMs - 1),"\#(n).25",10,"0.50000000","\#(n / 2).00","0"]"#
}

/// The close a synthetic bar at `index` must decode to, exactly
func syntheticClose(index: Int) -> Price {
    Price(Amount(baseUnits: Int128(1000 + index) * 1_000_000 + 250_000, asset: Fx.usdt), per: Fx.btc)
}

// MARK: - The clock for the back-off

/// Records every duration the retrieval asks to sleep, and returns at once
actor SleepRecorder {
    private(set) var asked: [Duration] = []

    func record(_ duration: Duration) { asked.append(duration) }

    nonisolated var sleep: @Sendable (Duration) async throws -> Void {
        { duration in await self.record(duration) }
    }
}

// MARK: - The in-memory store, the test's own conformer of the store protocol (OQ-S20)

/// The second conformer of the store protocol, beside the shipped file one; keeps each series by open time
actor BehavioralMemoryStore: OHLCVStore {
    private struct Key: Hashable { let market: String; let interval: BarInterval }
    private var series: [Key: [Date: OHLCVClientBar]] = [:]
    private var gapsByKey: [Key: Set<OHLCVGap>] = [:]

    func bars(market: String, interval: BarInterval) async throws -> [OHLCVClientBar] {
        (series[Key(market: market, interval: interval)] ?? [:]).values.sorted { $0.openTime < $1.openTime }
    }

    func keep(_ bars: [OHLCVClientBar], market: String, interval: BarInterval) async throws {
        let key = Key(market: market, interval: interval)
        var kept = series[key] ?? [:]
        for bar in bars { kept[bar.openTime] = bar }
        series[key] = kept
    }

    func gaps(market: String, interval: BarInterval) async throws -> [OHLCVGap] {
        (gapsByKey[Key(market: market, interval: interval)] ?? []).sorted { $0.after < $1.after }
    }

    func keep(_ gaps: [OHLCVGap], market: String, interval: BarInterval) async throws {
        gapsByKey[Key(market: market, interval: interval), default: []].formUnion(gaps)
    }
}

/// The store kinds the store contract runs against: the test's memory store and the library's file store
enum StoreKind: String, CaseIterable, Sendable, CustomStringConvertible {
    case memory
    case file

    var description: String { rawValue }

    func make(directory: URL = freshDirectory()) throws -> any OHLCVStore {
        switch self {
        case .memory: return BehavioralMemoryStore()
        case .file: return try FileOHLCVStore(directory: directory)
        }
    }
}

/// A new, empty directory under the temporary directory; never removed by the tests
func freshDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("layer-a2-behavioral", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

// MARK: - Typed errors, read through the adapter

/// An exchange's or a reference's own error as the client's typed error carries it: the code and the message
struct BehavioralExchangeError: Hashable, Sendable {
    let code: Int
    let message: String
}

/// A limit as the client's typed error carries it: the `Retry-After` it was given, if any
struct BehavioralLimit: Hashable, Sendable {
    let retryAfter: Duration?
}

/// Runs `body` and hands back what it threw, or nil
func caught<T>(_ body: () async throws -> T) async -> (any Error)? {
    do {
        _ = try await body()
        return nil
    } catch {
        return error
    }
}

/// § 1's error inside what a client threw, directly or as a decoding error's underlying error
func amountError(in error: (any Error)?) -> AmountError? {
    if let error = error as? AmountError { return error }
    if let error = error as? DecodingError {
        switch error {
        case .dataCorrupted(let context), .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context):
            return amountError(in: context.underlyingError)
        @unknown default:
            return nil
        }
    }
    return nil
}

// MARK: - Times and assets

func date(ms: Int64) -> Date { Date(timeIntervalSince1970: TimeInterval(ms) / 1000) }
func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }

enum Fx {
    /// Declared here with the exponents the tests compute from; the shipped constants are not relied on
    static let btc = try! Asset(symbol: "BTC", unitExponent: 8)
    static let usdt = try! Asset(symbol: "USDT", unitExponent: 6)
    static let pepe = try! Asset(symbol: "PEPE", unitExponent: 2)

    static let jan1Ms: Int64 = 1_704_067_200_000          // 2024-01-01T00:00:00Z, a Monday
    static let minuteMs: Int64 = 60_000
    static let dayMs: Int64 = 86_400_000
    static let weekMs: Int64 = 604_800_000
    static let farFutureMs: Int64 = 1_893_456_000_000     // 2030-01-01T00:00:00Z: every bar of 2024 is closed

    static let minute = BarInterval(count: 1, unit: .minute)
    static let day = BarInterval(count: 1, unit: .day)
    static let week = BarInterval(count: 1, unit: .week)

    static var btcusdt: BinanceOHLCVClient.MarketName { behavioralBinanceMarket("BTCUSDT", base: btc, quote: usdt) }
    static var pepeusdt: BinanceOHLCVClient.MarketName { behavioralBinanceMarket("PEPEUSDT", base: pepe, quote: usdt) }

    static func binance(_ session: any BehavioralSession, nowMs: Int64 = farFutureMs) -> BinanceOHLCVClient {
        behavioralBinanceClient(session: session, now: { date(ms: nowMs) })
    }

    static func usdtPerBTC(baseUnits: Int128) -> Price {
        Price(Amount(baseUnits: baseUnits, asset: usdt), per: btc)
    }
}

// MARK: - Binance fixtures

enum BinanceFixtures {
    /// Two closed daily BTCUSDT bars, 2024-01-01 and 2024-01-02
    // ASSUMED SHAPE
    static let dailyClosed = """
    [
      [1704067200000,"42283.58000000","44184.10000000","42180.77000000","44179.55000000","27174.29903000",1704153599999,"1169995226.85628160",1022839,"14271.31650000","614567587.07473680","0"],
      [1704153600000,"44179.55000000","45879.63000000","44148.34000000","44946.91000000","65146.40661000",1704239999999,"2944372529.89780870",2033389,"33583.72520000","1517981564.12436720","0"]
    ]
    """

    /// One closed daily bar whose numbers test exactness: "65000.00", a high below one USDT base unit, "0.00012500"
    // ASSUMED SHAPE
    static let exact = """
    [
      [1704240000000,"65000.00","65000.12345678","64999.99","65000.10","0.00012500",1704326399999,"8.12500000",7,"0.00006250","4.06250000","0"]
    ]
    """

    /// One closed daily PEPEUSDT bar priced below one USDT base unit per whole PEPE
    // ASSUMED SHAPE
    static let subUnit = """
    [
      [1704240000000,"0.00000123","0.00000130","0.00000120","0.00000125","1234567.89",1704326399999,"1.54320986",4321,"600000.00","0.75000000","0"]
    ]
    """

    /// The two closed daily bars, then the still-open bar of 2024-01-03; read it at now = 2024-01-03T12:00:00Z
    // ASSUMED SHAPE
    static let withOpen = """
    [
      [1704067200000,"42283.58000000","44184.10000000","42180.77000000","44179.55000000","27174.29903000",1704153599999,"1169995226.85628160",1022839,"14271.31650000","614567587.07473680","0"],
      [1704153600000,"44179.55000000","45879.63000000","44148.34000000","44946.91000000","65146.40661000",1704239999999,"2944372529.89780870",2033389,"33583.72520000","1517981564.12436720","0"],
      [1704240000000,"44946.91000000","45500.00000000","44700.00000000","45210.33000000","12000.50000000",1704326399999,"541824009.12000000",501234,"6000.25000000","270912004.56000000","0"]
    ]
    """
    static let withOpenNowMs: Int64 = 1_704_283_200_000

    /// One bar whose open is not a number
    // ASSUMED SHAPE
    static let malformed = """
    [
      [1704240000000,"6500O.00","65000.12","64999.99","65000.10","0.00012500",1704326399999,"8.12500000",7,"0.00006250","4.06250000","0"]
    ]
    """

    /// One bar whose volume has more fraction digits than BTC's base unit holds
    // ASSUMED SHAPE
    static let belowBaseUnit = """
    [
      [1704240000000,"65000.00","65000.12","64999.99","65000.10","0.000000001",1704326399999,"0.00006500",1,"0.000000000","0.00000000","0"]
    ]
    """

    /// One closed bar in which nothing traded
    // ASSUMED SHAPE
    static let zeroVolume = """
    [
      [1704240000000,"65000.00","65000.00","65000.00","65000.00","0.00000000",1704326399999,"0.00000000",0,"0.00000000","0.00000000","0"]
    ]
    """

    /// One closed weekly bar, Monday 2024-01-01 00:00 UTC through Sunday 23:59:59.999 UTC
    // ASSUMED SHAPE
    static let weekly = """
    [
      [1704067200000,"42283.58000000","47248.99000000","40750.00000000","41732.35000000","400812.12345000",1704671999999,"17520000000.00000000",9876543,"200406.06172500","8760000000.00000000","0"]
    ]
    """

    static let empty = "[]"

    /// Binance's error body for an unknown symbol, sent with HTTP 400
    // ASSUMED SHAPE
    static let invalidSymbol = #"{"code":-1121,"msg":"Invalid symbol."}"#
}

// MARK: - CoinMarketCap fixtures

enum CoinMarketCapFixtures {
    /// `/v1/cryptocurrency/listings/latest` with tags: BTC and ETH with no platform, USDT a stablecoin on Ethereum,
    /// and BARNEY, a reserved fake ranked 4000
    // ASSUMED SHAPE
    static let listings = """
    {
      "status": {"timestamp": "2024-01-03T12:00:00.000Z", "error_code": 0, "error_message": null, "elapsed": 12, "credit_count": 1, "notice": null, "total_count": 4},
      "data": [
        {"id": 1, "name": "Bitcoin", "symbol": "BTC", "slug": "bitcoin", "cmc_rank": 1, "num_market_pairs": 10000,
         "circulating_supply": 19590000, "total_supply": 19590000, "max_supply": 21000000, "infinite_supply": false,
         "date_added": "2010-07-13T00:00:00.000Z", "is_market_cap_included_in_calc": 1,
         "tags": ["mineable", "pow", "sha-256", "store-of-value", "layer-1"], "platform": null,
         "last_updated": "2024-01-03T12:00:00.000Z",
         "quote": {"USD": {"price": 45210.33, "volume_24h": 30000000000, "market_cap": 885000000000, "last_updated": "2024-01-03T12:00:00.000Z"}}},
        {"id": 1027, "name": "Ethereum", "symbol": "ETH", "slug": "ethereum", "cmc_rank": 2, "num_market_pairs": 8000,
         "circulating_supply": 120000000, "total_supply": 120000000, "max_supply": null, "infinite_supply": true,
         "date_added": "2015-08-07T00:00:00.000Z", "is_market_cap_included_in_calc": 1,
         "tags": ["pos", "smart-contracts", "layer-1", "ethereum-ecosystem"], "platform": null,
         "last_updated": "2024-01-03T12:00:00.000Z",
         "quote": {"USD": {"price": 2370.12, "volume_24h": 15000000000, "market_cap": 284000000000, "last_updated": "2024-01-03T12:00:00.000Z"}}},
        {"id": 825, "name": "Tether USDt", "symbol": "USDT", "slug": "tether", "cmc_rank": 3, "num_market_pairs": 70000,
         "circulating_supply": 91000000000, "total_supply": 94000000000, "max_supply": null, "infinite_supply": true,
         "date_added": "2015-02-25T00:00:00.000Z", "is_market_cap_included_in_calc": 1,
         "tags": ["stablecoin", "asset-backed-stablecoin", "ethereum-ecosystem"],
         "platform": {"id": 1027, "name": "Ethereum", "symbol": "ETH", "slug": "ethereum", "token_address": "0xdac17f958d2ee523a2206206994597c13d831ec7"},
         "last_updated": "2024-01-03T12:00:00.000Z",
         "quote": {"USD": {"price": 1.0001, "volume_24h": 40000000000, "market_cap": 91000000000, "last_updated": "2024-01-03T12:00:00.000Z"}}},
        {"id": 424242, "name": "Barney", "symbol": "BARNEY", "slug": "barney", "cmc_rank": 4000, "num_market_pairs": 2,
         "circulating_supply": 42000000, "total_supply": 42000000, "max_supply": null, "infinite_supply": false,
         "date_added": "2023-12-01T00:00:00.000Z", "is_market_cap_included_in_calc": 0,
         "tags": ["memes"],
         "platform": {"id": 1027, "name": "Ethereum", "symbol": "ETH", "slug": "ethereum", "token_address": "0x0000000000000000000000000000000000000042"},
         "last_updated": "2024-01-03T12:00:00.000Z",
         "quote": {"USD": {"price": 0.0000042, "volume_24h": 42, "market_cap": 176.4, "last_updated": "2024-01-03T12:00:00.000Z"}}}
      ]
    }
    """

    /// The error envelope for a missing key, sent with HTTP 401
    // ASSUMED SHAPE
    static let apiKeyMissing = """
    {"status": {"timestamp": "2024-01-03T12:00:00.000Z", "error_code": 1002, "error_message": "API key missing.", "elapsed": 0, "credit_count": 0}}
    """

    /// An error envelope sent with HTTP 200, to test that the envelope, not the status, carries the error
    // ASSUMED SHAPE (CoinMarketCap is not known to send error_code != 0 with HTTP 200; the case is a reading)
    static let invalidKeyWith200 = """
    {"status": {"timestamp": "2024-01-03T12:00:00.000Z", "error_code": 1001, "error_message": "This API Key is invalid.", "elapsed": 0, "credit_count": 0}}
    """
}

// MARK: - The retrieval over the feed

enum Retrieve {
    /// The retrieval over the Binance conformer on `feed`, keeping into `store`, its back-off recorded by `sleep`
    static func make<S: OHLCVStore>(_ feed: BehavioralBinanceFeed, store: S,
                                    sleep: SleepRecorder = SleepRecorder()) -> OHLCVRetrieval<BinanceOHLCVClient, S> {
        OHLCVRetrieval(client: Fx.binance(feed, nowMs: feed.nowMs), store: store, sleep: sleep.sleep)
    }

    /// A one-minute BTCUSDT series of `count` bars from 2024-01-01T00:00Z, all closed
    static func minuteFeed(count: Int, missing: Set<Int> = [], limited: [Int: String?] = [:]) -> BehavioralBinanceFeed {
        BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.minuteMs, count: count, missing: missing,
                              nowMs: Fx.farFutureMs, limited: limited)
    }

    /// The open time of the minute bar at `index`
    static func minute(_ index: Int) -> Date { date(ms: Fx.jan1Ms + Int64(index) * Fx.minuteMs) }

    /// The close time of the minute bar at `index`: its open time plus the interval, less one millisecond
    static func minuteClose(_ index: Int) -> Date { date(ms: Fx.jan1Ms + Int64(index + 1) * Fx.minuteMs - 1) }
}
