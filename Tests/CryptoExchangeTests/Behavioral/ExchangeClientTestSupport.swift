// ExchangeClientTestSupport.swift — the doubles and helpers every exchange client's suite shares.
//
// Shared by CryptoExchangeTests, CryptoHyperliquidTests, CryptoKrakenTests and CryptoCoinbaseTests:
// the builder makes this file and ExchangeClientContract.swift visible to the three plug-in targets
// (a test-support target or the files added to each target's sources).
//
// Projected from C30, C31, AR31–AR34, AR86, T40, T41, T49–T56, T60, T103 alone. No implementation seen.
// Every line that leans on a member the declarations do not have is marked `// INVENTED:`.

import CryptoAsset
import CryptoExchange
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Synchronization
import Testing

// MARK: - Numbers, from the exchange's text, exactly (§ 1's types; never a Double)

/// An amount of the asset named `symbol`, parsed exactly from its decimal text
func amount(_ text: String, _ symbol: String) throws -> Amount {
    try Amount(parsing: text, of: asset(symbol)) // INVENTED: CryptoAsset's exact text constructor for Amount (C1–C11 are not in this layer's input)
}

/// A price quoted in the asset named `quote`, parsed exactly from its decimal text
func price(_ text: String, _ quote: String) throws -> Price {
    try Price(parsing: text, in: asset(quote)) // INVENTED: CryptoAsset's exact text constructor for Price
}

/// A fraction (a funding rate), parsed exactly from its decimal text
func fraction(_ text: String) throws -> Fraction {
    try Fraction(parsing: text) // INVENTED: CryptoAsset's exact text constructor for Fraction
}

/// An asset by its symbol
func asset(_ symbol: String) throws -> Asset {
    try Asset(symbol: symbol) // INVENTED: CryptoAsset's asset-by-symbol constructor
}

/// An instant from the exchange's milliseconds since 1970, UTC
func ms(_ milliseconds: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
}

/// An instant from the exchange's ISO 8601 text, fractional seconds allowed
func iso(_ text: String) throws -> Date {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: text) { return date }
    let whole = ISO8601DateFormatter()
    whole.formatOptions = [.withInternetDateTime]
    guard let date = whole.date(from: text) else { throw ScriptError.badDate(text) }
    return date
}

/// A value of a client's own Codable type (an order id, a cursor) from the exchange's JSON text for it
func decoded<T: Decodable>(_ type: T.Type, json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

enum ScriptError: Error {
    case badDate(String)
    case noFillInLedger
}

// MARK: - C30's values, constructed (the declarations give no public initializer)

func makeMarket<Name>(
    _ name: Name, base: String, quote: String, lotSize: Amount, minimumOrder: Amount,
    maxLeverage: Int?, leverageSet: Int?, isPerpetual: Bool
) throws -> ExchangeClientMarket<Name> {
    ExchangeClientMarket(name: name, base: try asset(base), quote: try asset(quote), lotSize: lotSize, minimumOrder: minimumOrder, maxLeverage: maxLeverage, leverageSet: leverageSet, isPerpetual: isPerpetual) // INVENTED: C30's public memberwise initializer
}

func makeBook<Name>(_ market: Name, mid: Price, bestBid: Price, bestAsk: Price, volume: Amount, readAt: Date) -> ExchangeClientBook<Name> {
    ExchangeClientBook(market: market, mid: mid, bestBid: bestBid, bestAsk: bestAsk, volume: volume, readAt: readAt) // INVENTED: C30's public memberwise initializer
}

func makeOpenOrder<Name, OrderId>(_ id: OrderId, market: Name, side: ExchangeClientSide, units: Amount) -> ExchangeClientOpenOrder<Name, OrderId> {
    ExchangeClientOpenOrder(id: id, market: market, side: side, units: units) // INVENTED: C30's public memberwise initializer
}

func makePosition<Name>(_ market: Name, side: ExchangeClientSide, units: Amount, entryPrice: Price, mark: Price, liquidationPrice: Price?) -> ExchangeClientPosition<Name> {
    ExchangeClientPosition(market: market, side: side, units: units, entryPrice: entryPrice, mark: mark, liquidationPrice: liquidationPrice) // INVENTED: C30's public memberwise initializer
}

func makeMode(_ name: String, allowsTransfer: Bool, allowsIsolatedMargin: Bool, alternatives: [String]) -> ExchangeClientAccountMode {
    ExchangeClientAccountMode(name: name, allowsTransfer: allowsTransfer, allowsIsolatedMargin: allowsIsolatedMargin, alternatives: alternatives) // INVENTED: C30's public memberwise initializer
}

func makeAccountState<Name>(balance: Amount, withdrawable: Amount, positions: [ExchangeClientPosition<Name>], mode: ExchangeClientAccountMode, readAt: Date) -> ExchangeClientAccountState<Name> {
    ExchangeClientAccountState(balance: balance, withdrawable: withdrawable, positions: positions, mode: mode, readAt: readAt) // INVENTED: C30's public memberwise initializer
}

func makeKeyFacts(canTrade: Bool, canTransfer: Bool, canWithdraw: Bool, approvedBy: String?, validUntil: Date?) -> ExchangeClientKeyFacts {
    ExchangeClientKeyFacts(canTrade: canTrade, canTransfer: canTransfer, canWithdraw: canWithdraw, approvedBy: approvedBy, validUntil: validUntil) // INVENTED: C30's public memberwise initializer
}

func makeBudget(limit: Int, remaining: Int, resetsAt: Date) -> ExchangeClientRequestBudget {
    ExchangeClientRequestBudget(limit: limit, remaining: remaining, resetsAt: resetsAt) // INVENTED: C30's public memberwise initializer
}

func makeNotice<Name>(_ kind: ExchangeClientNotice<Name>.Kind, market: Name, effectiveAt: Date, text: String) -> ExchangeClientNotice<Name> {
    ExchangeClientNotice(kind: kind, market: market, effectiveAt: effectiveAt, text: text) // INVENTED: C30's public memberwise initializer
}

// MARK: - The ledger, compared without its cursors (each client's cursor is its own opaque type)

/// One ledger item's values without the cursor it carries
enum LedgerLine<Name: Hashable & Sendable, OrderId: Hashable & Sendable>: Hashable {
    case fill(market: Name, side: ExchangeClientSide, units: Amount, price: Price, fee: Amount, order: OrderId, closedBy: ExchangeClientCloseReason?, time: Date)
    case funding(market: Name, amount: Amount, rate: Fraction, time: Date)
    case deposit(Amount, time: Date)
    case withdrawal(Amount, time: Date)
    case internalMove(Amount, from: String, to: String, time: Date)

    var time: Date {
        switch self {
        case let .fill(_, _, _, _, _, _, _, time): time
        case let .funding(_, _, _, time): time
        case let .deposit(_, time): time
        case let .withdrawal(_, time): time
        case let .internalMove(_, _, _, time): time
        }
    }
}

func line<Name, OrderId, Cursor>(_ item: ExchangeClientLedgerItem<Name, OrderId, Cursor>) -> LedgerLine<Name, OrderId> {
    switch item {
    case let .fill(market, side, units, price, fee, order, closedBy, time, _, _):
        .fill(market: market, side: side, units: units, price: price, fee: fee, order: order, closedBy: closedBy, time: time)
    case let .funding(market, amount, rate, time, _):
        .funding(market: market, amount: amount, rate: rate, time: time)
    case let .deposit(amount, time, _):
        .deposit(amount, time: time)
    case let .withdrawal(amount, time, _):
        .withdrawal(amount, time: time)
    case let .internalMove(amount, from, to, time, _):
        .internalMove(amount, from: from, to: to, time: time)
    }
}

func cursor<Name, OrderId, Cursor>(_ item: ExchangeClientLedgerItem<Name, OrderId, Cursor>) -> Cursor {
    switch item {
    case let .fill(_, _, _, _, _, _, _, _, cursor, _): cursor
    case let .funding(_, _, _, _, cursor): cursor
    case let .deposit(_, _, cursor): cursor
    case let .withdrawal(_, _, cursor): cursor
    case let .internalMove(_, _, _, _, cursor): cursor
    }
}

// MARK: - An order's outcome, compared without the time a client stamps it with

enum OrderOutcome<OrderId: Hashable & Sendable>: Hashable {
    case filled(units: Amount, at: Price, id: OrderId)
    case partlyFilled(units: Amount, at: Price, id: OrderId)
    // Wiring, 2026-10-06 (the parent): C30 gained `resting(id:time:)` at the owner's word; the exhaustive switch below needs it. No assertion changed.
    case resting(id: OrderId)
    case cancelledBeforeAccepted
    case cancelled(id: OrderId)
    case refused(text: String)
}

func outcome<OrderId>(_ result: ExchangeClientOrderResult<OrderId>) -> OrderOutcome<OrderId> {
    switch result {
    case let .filled(units, at, id, _): .filled(units: units, at: at, id: id)
    case let .partlyFilled(units, at, id, _): .partlyFilled(units: units, at: at, id: id)
    case let .resting(id, _): .resting(id: id)
    case .cancelledBeforeAccepted: .cancelledBeforeAccepted
    case let .cancelled(id): .cancelled(id: id)
    case let .refused(_, text): .refused(text: text)
    }
}

func refusalCode<OrderId>(_ result: ExchangeClientOrderResult<OrderId>) -> String? {
    if case let .refused(code, _) = result { return code }
    return nil
}

// MARK: - The scripted session (never a network call)

/// One scripted answer, chosen by a needle found in the request's URL or body; served to every request it matches
struct ScriptedRoute: Sendable {
    let needle: String
    let status: Int
    let headers: [String: String]
    let body: Data
    /// An exchange that does not answer: the session throws this instead (T56)
    let failure: URLError.Code?

    static func json(_ needle: String, _ body: String, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) -> ScriptedRoute {
        ScriptedRoute(needle: needle, status: status, headers: headers, body: Data(body.utf8), failure: nil)
    }

    static func unreachable(_ needle: String) -> ScriptedRoute {
        ScriptedRoute(needle: needle, status: 0, headers: [:], body: Data(), failure: .timedOut)
    }
}

/// The double a client takes as its `session:`; it answers from routes and keeps every request
final class ScriptedSession: ExchangeClientSession, Sendable { // INVENTED: ExchangeClientSession, the URLSession-shaped seam a client takes as `session:` (AR31 names FOSFoundation's mockable session; the builder binds this double to it)
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
        if let failure = route.failure { throw URLError(failure) }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: route.status, httpVersion: "HTTP/1.1", headerFields: route.headers)
        else { throw URLError(.badURL) }
        return (route.body, response)
    }

    /// Every request the client made, in order
    var requests: [URLRequest] { kept.withLock { $0 } }

    /// How many requests carried `needle` in their URL or body
    func count(matching needle: String) -> Int {
        requests.filter { Self.urlAndBody(of: $0).contains(needle) }.count
    }

    /// Everything that left the client: methods, URLs, every header, every body
    var everythingSent: String {
        requests.map { request in
            let headers = (request.allHTTPHeaderFields ?? [:]).map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
            return "\(request.httpMethod ?? "GET") \(Self.urlAndBody(of: request))\n\(headers)"
        }.joined(separator: "\n\n")
    }

    static func urlAndBody(of request: URLRequest) -> String {
        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        return "\(request.url?.absoluteString ?? "") \(body)"
    }
}

/// Every line a client logs; handed to a client at construction (T40: no key in a log line)
final class LogCapture: Sendable {
    private let kept = Mutex<[String]>([])

    func record(_ line: String) {
        kept.withLock { $0.append(line) }
    }

    var lines: [String] { kept.withLock { $0 } }
}

/// Asserts each text appears somewhere the client sent
func expectSent(_ texts: [String], in session: ScriptedSession, sourceLocation: SourceLocation = #_sourceLocation) {
    let sent = session.everythingSent
    for text in texts {
        #expect(sent.contains(text), "expected the request to carry \(text)", sourceLocation: sourceLocation)
    }
}

/// Asserts no secret appears in a text, ignoring case (hex keys travel in either case)
func expectNoSecret(_ secrets: [String], in text: String, _ place: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let haystack = text.lowercased()
    for secret in secrets where !secret.isEmpty {
        #expect(!haystack.contains(secret.lowercased()), "a key appeared in \(place)", sourceLocation: sourceLocation)
    }
}
