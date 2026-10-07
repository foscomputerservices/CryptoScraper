// Fixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The recorded responses, and a session that answers from them. Every Binance file under Resources/Binance was
// recorded from api.binance.com on 2026-10-04 at 07:51 UTC, except error-limit-429.json, which is Binance's
// documented -1003 body (a live 429 would mean abusing the limit). Resources/L21 holds the first 1,200 candles of
// the POC's btcusdt-binance-1d.json, sliced as raw text so not one of its number tokens was re-written.

enum Recorded {
    static func data(_ path: String) -> Data {
        // SwiftPM lays a `.copy("Resources")` folder at the bundle's root on one toolchain and inside `Resources/` on
        // another (Xcode 26.6's puts it one level deeper than Swift 6.4's), so both places are tried.
        let base = Bundle.module.resourceURL!
        for candidate in [base.appendingPathComponent("Resources/\(path)"), base.appendingPathComponent(path)] {
            if let data = try? Data(contentsOf: candidate) { return data }
        }
        fatalError("No recorded fixture \(path) under \(base.path)")
    }

    static let page1 = data("Binance/klines-btcusdt-1d-page1.json")
    static let page2 = data("Binance/klines-btcusdt-1d-page2.json")
    static let gapPage = data("Binance/klines-btcusdt-4h-gap.json")
    static let latest = data("Binance/klines-btcusdt-1d-latest.json")
    static let invalidSymbol = data("Binance/error-invalid-symbol.json")
    static let limitBody = data("Binance/error-limit-429.json")
    static let exchangeInfo = data("Binance/exchangeinfo-btcusdt.json")
    static let l21Candles = data("L21/btcusdt-binance-1d-first1200.json")

    // The kline rows' raw number texts, as Binance sent them: [open, high, low, close, volume] and the open time.
    static func rawRows(_ data: Data) -> [(openTime: Int64, texts: [String])] {
        let rows = try! JSONSerialization.jsonObject(with: data) as! [[Any]]
        return rows.map { row in
            ((row[0] as! NSNumber).int64Value, (1...5).map { row[$0] as! String })
        }
    }

    // The instant of the latest recording: the response's Date header.
    static let recordedAt = Date(milliseconds: 1_791_150_716_000)       // 2026-10-04T07:51:56Z

    // The first page's range: the first daily open through the open of the 1,200th day.
    static let rangeStart = Date(milliseconds: 1_502_928_000_000)        // 2017-08-17
    static let page1Last = Date(milliseconds: 1_589_241_600_000)         // 2020-05-12
    static let rangeEnd = Date(milliseconds: 1_606_521_600_000)          // 2020-11-28

    static let gapStart = Date(milliseconds: 1_517_875_200_000)          // 2018-02-06
    static let gapEnd = Date(milliseconds: 1_518_307_200_000)            // 2018-02-11
}

extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    var milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}

enum Binance {
    static let btcusdt = try! BinanceMarketName(validating: "BTCUSDT")
    // Carried in step 4c of the identity PR: the market is Binance's recorded exchange information for BTCUSDT, its
    // holdings Binance's declared BTC and USDT, both at 8, declared in the shared registry by the market's
    // initializer, whichever test runs first
    static let market = try! BinanceMarket(name: btcusdt, baseSymbol: AssetSymbol(validating: "BTC"), baseDecimals: 8,
                                           quoteSymbol: AssetSymbol(validating: "USDT"), quoteDecimals: 8)
    static let btc: AssetInstance = market.base!
    static let usdt: AssetInstance = market.quote!
    static let day = BarInterval(count: 1, unit: .day)
    static let fourHours = BarInterval(count: 4, unit: .hour)
}

// A reply the recorded session gives.
struct Reply: Sendable {
    let status: Int
    let body: Data
    let headers: [String: String]

    static func ok(_ body: Data) -> Reply { .init(status: 200, body: body, headers: [:]) }
    static let emptyPage = Reply.ok(Data("[]".utf8))
}

// A URLSessionProtocol that answers each request from the recorded files through `route`, notes every request, and
// never touches the network: the task it returns is an inert `data:` task.
final class ReplaySession: URLSessionProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var noted: [URLRequest] = []
    private let route: @Sendable (URLRequest, Int) -> Reply

    // `route` receives the request and its index among the requests so far.
    init(route: @escaping @Sendable (URLRequest, Int) -> Reply) {
        self.route = route
    }

    var requests: [URLRequest] {
        lock.withLock { noted }
    }

    func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        let index = lock.withLock {
            noted.append(request)
            return noted.count - 1
        }
        let reply = route(request, index)
        var headers = ["Content-Type": "application/json;charset=UTF-8"]
        headers.merge(reply.headers) { _, new in new }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: headers)
        completionHandler(reply.body, response, nil)
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("ReplaySession is made with a route")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

extension URLRequest {
    func query(_ name: String) -> String? {
        URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

// Binance's klines answered from the recorded klines as Binance would: the rows whose open time falls in
// [startTime, endTime], at most `limit`, the rows themselves untouched; exchangeInfo from its recording; a request
// with no startTime is the latest kline.
func binanceRoute(_ request: URLRequest, _: Int) -> Reply {
    if request.url!.path.hasSuffix("exchangeInfo") {
        return .ok(Recorded.exchangeInfo)
    }
    guard let start = request.query("startTime").flatMap({ Int64($0) }) else {
        return .ok(Recorded.latest)
    }
    let end = request.query("endTime").flatMap { Int64($0) } ?? .max
    let limit = request.query("limit").flatMap { Int($0) } ?? 500
    let source: [Data] = request.query("interval") == "4h" ? [Recorded.gapPage] : [Recorded.page1, Recorded.page2]
    let rows = source
        .flatMap { try! JSONSerialization.jsonObject(with: $0) as! [[Any]] }
        .filter { row in
            let open = (row[0] as! NSNumber).int64Value
            return open >= start && open <= end
        }
        .prefix(limit)
    return .ok(try! JSONSerialization.data(withJSONObject: Array(rows)))
}

func client(_ session: ReplaySession, now: Date = Recorded.recordedAt, markets: [BinanceMarket] = [Binance.market]) -> BinanceOHLCVClient {
    BinanceOHLCVClient(session: session, markets: markets, now: { now })
}

// An amount as plain decimal text in whole units, trailing zeros and a bare point stripped: the form JavaScript's
// JSON.stringify writes a number in, for the numbers the recordings carry.
func decimalText(_ amount: Amount) -> String {
    let exponent = try! AssetRegistry.shared.decimals(of: amount.instance)
    let negative = amount.baseUnits < 0
    var digits = String(amount.baseUnits.magnitude)
    if digits.count <= exponent {
        digits = String(repeating: "0", count: exponent - digits.count + 1) + digits
    }
    var whole = String(digits.dropLast(exponent))
    var fraction = String(digits.suffix(exponent))
    while fraction.hasSuffix("0") {
        fraction.removeLast()
    }
    if whole.isEmpty { whole = "0" }
    let text = fraction.isEmpty ? whole : "\(whole).\(fraction)"
    return negative ? "-" + text : text
}

// A price as the decimal text of the quote per one whole base unit.
func decimalText(_ price: Price) -> String {
    decimalText(price.cost(of: try! Amount(whole: 1, of: price.base)))
}

// A feed's number text with its trailing zeros stripped: "4261.48000000" → "4261.48", "3850.00000000" → "3850".
func strippedText(_ text: String) -> String {
    guard text.contains(".") else { return text }
    var text = text
    while text.hasSuffix("0") {
        text.removeLast()
    }
    if text.hasSuffix(".") {
        text.removeLast()
    }
    return text
}

// An OHLCVHistoryStore in memory, the second conformer every retrieval test runs against.
actor MemoryStore: OHLCVHistoryStore {
    typealias MarketName = BinanceMarketName

    private struct Key: Hashable {
        let market: BinanceMarketName
        let interval: BarInterval
    }

    private var kept: [Key: OHLCVHistory] = [:]

    func lastBar(market: BinanceMarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        kept[Key(market: market, interval: interval)]?.bars.last
    }

    func append(_ bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap], market: BinanceMarketName, interval: BarInterval) async throws {
        let key = Key(market: market, interval: interval)
        let old = kept[key] ?? OHLCVHistory(bars: [], gaps: [])
        kept[key] = OHLCVHistory(bars: old.bars + bars, gaps: old.gaps + gaps)
    }

    func history(market: BinanceMarketName, interval: BarInterval) async throws -> OHLCVHistory {
        kept[Key(market: market, interval: interval)] ?? OHLCVHistory(bars: [], gaps: [])
    }
}

// The two conformers of the store protocol each retrieval test runs against.
enum ContractStoreKind: String, CaseIterable, Sendable {
    case memory
    case file
}

// A fresh temporary directory per call, never removed by the tests (the system clears its temporary directory).
func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CryptoOHLCVTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

// Waits a retrieval took, noted instead of slept.
final class WaitLog: @unchecked Sendable {
    private let lock = NSLock()
    private var noted: [Duration] = []

    var waits: [Duration] {
        lock.withLock { noted }
    }

    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in lock.withLock { noted.append(duration) } }
    }
}

// Runs `body` with a retrieval over the recorded client and the store of `kind`, then hands back the store's view.
func withRetrieval<Result>(
    _ kind: ContractStoreKind,
    session: ReplaySession,
    backoff: OHLCVHistoryBackoff = .init(),
    waits: WaitLog = WaitLog(),
    directory: URL = temporaryDirectory(),
    _ body: (any RetrievalUnderTest) async throws -> Result
) async throws -> Result {
    switch kind {
    case .memory:
        let store = MemoryStore()
        return try await body(Bound(
            retrieval: OHLCVHistoryRetrieval(client: client(session), store: store, backoff: backoff, sleep: waits.sleep),
            historyOf: { try await store.history(market: $0, interval: $1) }
        ))
    case .file:
        let store = OHLCVHistoryFileStore<BinanceMarketName>(directory: directory)
        return try await body(Bound(
            retrieval: OHLCVHistoryRetrieval(client: client(session), store: store, backoff: backoff, sleep: waits.sleep),
            historyOf: { try await store.history(market: $0, interval: $1) }
        ))
    }
}

// The retrieval and its store's view, whatever the store's type.
protocol RetrievalUnderTest: Sendable {
    func retrieve(from: Date, through: Date, interval: BarInterval) async throws -> OHLCVHistoryRetrievalResult
    func history(_ interval: BarInterval) async throws -> OHLCVHistory
}

struct Bound<Store: OHLCVHistoryStore>: RetrievalUnderTest where Store.MarketName == BinanceMarketName {
    let retrieval: OHLCVHistoryRetrieval<BinanceOHLCVClient, Store>
    let historyOf: @Sendable (BinanceMarketName, BarInterval) async throws -> OHLCVHistory

    func retrieve(from: Date, through: Date, interval: BarInterval) async throws -> OHLCVHistoryRetrievalResult {
        try await retrieval.retrieve(market: Binance.btcusdt, interval: interval, from: from, through: through)
    }

    func history(_ interval: BarInterval) async throws -> OHLCVHistory {
        try await historyOf(Binance.btcusdt, interval)
    }
}
