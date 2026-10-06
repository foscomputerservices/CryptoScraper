// KrakenClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Kraken spot's exchange client (C31): its public and private REST, its signing, its typed errors
///
/// A private request is a form-encoded POST carrying an always-increasing nonce, signed with the API secret
/// (AR32): `API-Sign` is the base64 of HMAC-SHA512, keyed with the decoded secret, over the request's path and the
/// SHA-256 of the nonce and the body. Every request is one call of FOSFoundation's fetch.
///
/// ```swift
/// let client = KrakenClient(credential: try KrakenCredential(apiKey: key, base64Secret: secret))
/// let xbtusd = try KrakenMarketName(validating: "XBTUSD")
/// let book = try await client.orderBook(market: xbtusd)
/// ```
///
/// **Accounts.** A Kraken key is bound to one account, so the `account` a member takes is not sent.
///
/// **Numbers.** A market's assets are Kraken's own, by their alternative names ("XBT", "USD") at Kraken's decimals;
/// every number Kraken sends as text is decoded exactly. Kraken spot has no test market.
public struct KrakenClient: ExchangeClient {
    public typealias Credential = KrakenCredential
    public typealias MarketName = KrakenMarketName
    public typealias OrderId = KrakenOrderId
    public typealias Cursor = KrakenLedgerCursor

    /// Kraken's REST root
    public static let productionURL = URL(string: "https://api.kraken.com")!

    private let credential: KrakenCredential?
    private let baseURL: URL
    private let statusURL: URL
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let state: KrakenClientState
    private let tally: RequestTally

    /// - Parameters:
    ///   - credential: The API key and its secret; `nil` for a client that only reads the markets and the books
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock: each private request's nonce is its milliseconds, kept increasing
    public init(
        credential: KrakenCredential?,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credential = credential
        self.baseURL = Self.productionURL
        self.statusURL = URL(string: "https://status.kraken.com/api/v2/scheduled-maintenances/upcoming.json")!
        self.session = session
        self.now = now
        self.state = KrakenClientState()
        self.tally = RequestTally(window: Self.counterWindow)
    }

    public var hasTestMarket: Bool { false }

    // MARK: Markets and books

    public func markets() async throws -> [ExchangeClientMarket<KrakenMarketName>] {
        let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [])
        var markets: [ExchangeClientMarket<KrakenMarketName>] = []
        for (key, info) in pairs.result.sorted(by: { $0.key < $1.key }) {
            let pair = try await self.pair(key: key, info: info)
            markets.append(ExchangeClientMarket(
                name: pair.name, base: pair.base, quote: pair.quote,
                lotSize: try WireDecimal(digits: 1, fractionDigits: info.lotDecimals).amount(of: pair.base),
                minimumOrder: try info.ordermin.amount(of: pair.base),
                maxLeverage: info.leverageBuy.max(), leverageSet: nil, isPerpetual: false
            ))
        }
        return markets
    }

    public func orderBook(market: KrakenMarketName) async throws -> ExchangeClientBook<KrakenMarketName> {
        let pair = try await self.pair(market)
        let ticker: KrakenResult<[String: KrakenTicker]> = try await publicGet("Ticker", [URLQueryItem(name: "pair", value: market.text)])
        guard let entry = ticker.result.first?.value else {
            throw KrakenClientError.unknownMarket(market)
        }
        return ExchangeClientBook(
            market: market,
            mid: try WireDecimal.midpoint(entry.bid, entry.ask).price(of: pair.quote, per: pair.base),
            bestBid: try entry.bid.price(of: pair.quote, per: pair.base),
            bestAsk: try entry.ask.price(of: pair.quote, per: pair.base),
            volume: try entry.dayVolume.amount(of: pair.base),
            readAt: now()
        )
    }

    // MARK: Orders

    public func placeOrder(market: KrakenMarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                           immediateOrCancel: Bool, reduceOnly: Bool, account: String) async throws -> ExchangeClientOrderResult<KrakenOrderId> {
        let pair = try await self.pair(market)
        guard size.asset == pair.base, limit.base == pair.base, limit.quote == pair.quote else {
            throw KrakenClientError.wrongAsset
        }
        var fields = [("ordertype", "limit"), ("type", side == .buy ? "buy" : "sell"), ("volume", WireDecimal(size).text),
                      ("pair", market.text), ("price", WireDecimal(limit).text)]
        if immediateOrCancel { fields.append(("timeinforce", "IOC")) }
        if reduceOnly { fields.append(("reduce_only", "true")) }

        let added: KrakenResult<KrakenAddedOrder>
        do {
            added = try await privatePost("AddOrder", fields)
        } catch let error as KrakenAPIError where error.messages.allSatisfy({ $0.hasPrefix("EOrder:") }) {
            let message = error.messages.first ?? "EOrder:"
            return .refused(code: "EOrder", text: String(message.dropFirst("EOrder:".count)))
        }
        guard let txid = added.result.txid.first else {
            throw KrakenClientError.refused("Kraken answered the order with no transaction id")
        }
        let id = try KrakenOrderId(validating: txid)
        let queried: KrakenResult<[String: KrakenOrderInfo]> = try await privatePost("QueryOrders", [("txid", txid)])
        guard let order = queried.result[txid] else {
            throw KrakenClientError.refused("Kraken does not know the order it took: \(txid)")
        }
        let executed = try order.volExec.amount(of: pair.base)
        let time = order.closetm ?? order.opentm
        if executed.isZero {
            switch order.status {
            case "canceled", "expired": return .cancelled(id: id)
            default: return .resting(id: id, time: time)
            }
        }
        let price = try order.price.price(of: pair.quote, per: pair.base)
        return executed == size
            ? .filled(units: executed, at: price, id: id, time: time)
            : .partlyFilled(units: executed, at: price, id: id, time: time)
    }

    public func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<KrakenMarketName, KrakenOrderId>] {
        let open: KrakenResult<KrakenOpenOrders> = try await privatePost("OpenOrders", [])
        var orders: [ExchangeClientOpenOrder<KrakenMarketName, KrakenOrderId>] = []
        for (txid, order) in open.result.open.sorted(by: { $0.key < $1.key }) {
            let market = try KrakenMarketName(validating: order.descr.pair)
            let pair = try await self.pair(market)
            orders.append(ExchangeClientOpenOrder(
                id: try KrakenOrderId(validating: txid), market: market, side: order.descr.type == "buy" ? .buy : .sell,
                units: try order.vol.amount(of: pair.base) - order.volExec.amount(of: pair.base)
            ))
        }
        return orders
    }

    public func cancelOrder(_ id: KrakenOrderId, market: KrakenMarketName, account: String) async throws {
        let cancelled: KrakenResult<KrakenCancelled> = try await privatePost("CancelOrder", [("txid", id.text)])
        guard cancelled.result.count > 0 else {
            throw KrakenClientError.refused("Kraken cancelled no order for \(id.text)")
        }
    }

    // MARK: The account

    /// The account's equivalent balance and free margin in USD, and its open margin positions
    public func accountState(account: String) async throws -> ExchangeClientAccountState<KrakenMarketName> {
        let usd = try await asset(key: "ZUSD")
        let balance: KrakenResult<KrakenTradeBalance> = try await privatePost("TradeBalance", [("asset", "ZUSD")])
        let open: KrakenResult<[String: KrakenOpenPosition]> = try await privatePost("OpenPositions", [("docalcs", "true")])
        var positions: [ExchangeClientPosition<KrakenMarketName>] = []
        for (_, held) in open.result.sorted(by: { $0.key < $1.key }) {
            let market = try KrakenMarketName(validating: held.pair)
            let pair = try await self.pair(market)
            let units = try held.vol.amount(of: pair.base) - held.volClosed.amount(of: pair.base)
            guard !units.isZero else { continue }
            positions.append(ExchangeClientPosition(
                market: market, side: held.type == "buy" ? .buy : .sell, units: units,
                entryPrice: try Self.price(of: held.cost, per: held.vol, pair),
                mark: try Self.price(of: held.value, per: WireDecimal(units), pair),
                liquidationPrice: nil
            ))
        }
        return ExchangeClientAccountState(
            balance: try balance.result.eb.amount(of: usd),
            withdrawable: try balance.result.mf.amount(of: usd),
            positions: positions,
            mode: ExchangeClientAccountMode(name: "spot", allowsTransfer: false, allowsIsolatedMargin: false, alternatives: []),
            readAt: now()
        )
    }

    public func ledgerItems(account: String, since: KrakenLedgerCursor?) async throws -> [ExchangeClientLedgerItem<KrakenMarketName, KrakenOrderId, KrakenLedgerCursor>] {
        let start = since.map { [("start", $0.seconds.text)] } ?? []
        let trades: KrakenResult<KrakenTrades> = try await privatePost("TradesHistory", start)
        let ledger: KrakenResult<KrakenLedger> = try await privatePost("Ledgers", start)

        var items: [(WireDecimal, ExchangeClientLedgerItem<KrakenMarketName, KrakenOrderId, KrakenLedgerCursor>)] = []
        for trade in trades.result.trades.values {
            let market = try KrakenMarketName(validating: trade.pair)
            let pair = try await self.pair(market)
            items.append((trade.time, .fill(
                market: market, side: trade.type == "buy" ? .buy : .sell,
                units: try trade.vol.amount(of: pair.base), price: try trade.price.price(of: pair.quote, per: pair.base),
                fee: try trade.fee.amount(of: pair.quote), order: try KrakenOrderId(validating: trade.ordertxid), closedBy: nil,
                time: KrakenLedgerCursor(seconds: trade.time).time, cursor: KrakenLedgerCursor(seconds: trade.time)
            )))
        }
        for entry in ledger.result.ledger.values {
            let cursor = KrakenLedgerCursor(seconds: entry.time)
            switch entry.type {
            case "deposit":
                items.append((entry.time, .deposit(try entry.amount.amount(of: try await asset(key: entry.asset)), time: cursor.time, cursor: cursor)))
            case "withdrawal":
                items.append((entry.time, .withdrawal(try entry.amount.amount(of: try await asset(key: entry.asset)), time: cursor.time, cursor: cursor)))
            case "transfer":
                items.append((entry.time, .internalMove(try entry.amount.amount(of: try await asset(key: entry.asset)), from: entry.subtype, to: entry.asset, time: cursor.time, cursor: cursor)))
            default:
                // A trade's ledger entry is its fill, read from TradesHistory with its order; the other kinds (margin,
                // rollover, staking…) have no case in C30 and are not handed up (a reading for the owner's pen).
                continue
            }
        }
        return items.sorted { Self.seconds($0.0) < Self.seconds($1.0) }.map(\.1)
    }

    // A cost over a volume, exactly: Kraken states a cost at the pair's cost decimals, which may be finer than the
    // quote asset's own, so both are scaled by the same power of ten until the cost fits, which leaves the ratio as it was.
    static func price(of cost: WireDecimal, per volume: WireDecimal, _ pair: KrakenPair) throws -> Price {
        let shift = max(0, cost.fractionDigits - pair.quote.unitExponent)
        let scaledCost = WireDecimal(digits: cost.digits, fractionDigits: cost.fractionDigits - shift)
        let scaledVolume = WireDecimal(digits: volume.digits * WireDecimal.powerOfTen(shift), fractionDigits: volume.fractionDigits)
        return Price(try scaledCost.amount(of: pair.quote), per: try scaledVolume.amount(of: pair.base))
    }

    private static func seconds(_ time: WireDecimal) -> Int128 {
        time.digits * WireDecimal.powerOfTen(10 - min(time.fractionDigits, 10))
    }

    public func setLeverage(_ leverage: Int, market: KrakenMarketName, isolated: Bool, account: String) async throws {
        throw KrakenClientError.leverageNotSettable
    }

    public func transfer(_ amount: Amount, from: String, to: String) async throws {
        throw KrakenClientError.transferNotOffered
    }

    public func keyFacts() async throws -> ExchangeClientKeyFacts {
        throw KrakenClientError.keyFactsNotOffered
    }

    /// Kraken's REST call counter, Starter tier, counted by this client: at most 15, decaying 0.33 a second, so a
    /// full counter clears in 45 seconds; the client counts its own requests in 45-second windows
    public func requestBudget() async throws -> ExchangeClientRequestBudget {
        let reading = tally.reading(at: now())
        return ExchangeClientRequestBudget(limit: Self.counterLimit, remaining: max(0, Self.counterLimit - reading.count), resetsAt: reading.resetsAt)
    }

    static let counterLimit = 15
    static let counterWindow: Duration = .seconds(45)

    /// The maintenance Kraken schedules on its status page, each from its start to its end; every kind it posts
    public func maintenanceWindows() async throws -> [DateInterval] {
        let page: KrakenStatusPage = try await ClientFetch.send(statusURL, session: session, errorType: KrakenAPIError.self, errorForResponse: { _, _ in nil })
        return page.scheduledMaintenances.compactMap { maintenance in
            guard let start = maintenance.start, let end = maintenance.end, start <= end else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    /// A notice for each pair Kraken lists in a state other than "online", effective when read: Kraken states no date
    public func notices() async throws -> [ExchangeClientNotice<KrakenMarketName>] {
        let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [])
        let read = now()
        return try pairs.result.sorted(by: { $0.key < $1.key }).compactMap { key, info in
            guard info.status != "online" else { return nil }
            return ExchangeClientNotice(kind: info.status == "delisted" ? .delisting : .halt,
                                        market: try KrakenMarketName(validating: key), effectiveAt: read, text: info.status)
        }
    }

    // MARK: The wire

    // A market's pair and assets, asked of AssetPairs and Assets once and kept under both of Kraken's names for it.
    private func pair(_ market: KrakenMarketName) async throws -> KrakenPair {
        if let known = await state.pair(market) {
            return known
        }
        let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [URLQueryItem(name: "pair", value: market.text)])
        guard let entry = pairs.result.first(where: { $0.key == market.text || $0.value.altname == market.text }) else {
            throw KrakenClientError.unknownMarket(market)
        }
        return try await pair(key: entry.key, info: entry.value)
    }

    private func pair(key: String, info: KrakenPairInfo) async throws -> KrakenPair {
        let pair = KrakenPair(name: try KrakenMarketName(validating: key), base: try await asset(key: info.base), quote: try await asset(key: info.quote))
        await state.keep(pair, as: [pair.name, try KrakenMarketName(validating: info.altname)])
        return pair
    }

    // An asset by Kraken's key ("XXBT", "ZUSD"), at its alternative name and decimals, asked of Assets once.
    private func asset(key: String) async throws -> Asset {
        if let known = await state.asset(key) {
            return known
        }
        let assets: KrakenResult<[String: KrakenAssetEntry]> = try await publicGet("Assets", [])
        for (assetKey, entry) in assets.result {
            if let asset = try? Asset(symbol: entry.altname, unitExponent: entry.decimals) { // an asset Kraken names in a way AssetSymbol refuses is no asset here
                await state.keep(asset, as: assetKey)
            }
        }
        guard let asset = await state.asset(key) else {
            throw KrakenClientError.unknownAsset(key)
        }
        return asset
    }

    private func publicGet<Value: Decodable & Sendable>(_ method: String, _ query: [URLQueryItem]) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent("0/public/\(method)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        return try await ClientFetch.send(components.url!, session: session, errorType: KrakenAPIError.self, errorForResponse: hook)
    }

    // A private request: the form body with its nonce first, signed (AR32).
    private func privatePost<Value: Decodable & Sendable>(_ method: String, _ fields: [(String, String)]) async throws -> Value {
        guard let credential else {
            throw KrakenClientError.noCredential
        }
        let path = "/0/private/\(method)"
        let nonce = await state.nextNonce(at: now().wireMilliseconds)
        let body = Self.formBody([("nonce", String(nonce))] + fields)
        let signature = Self.signature(path: path, nonce: String(nonce), body: body, secret: credential.secret)
        return try await ClientFetch.send(
            baseURL.appendingPathComponent(String(path.dropFirst())), method: "POST", body: Data(body.utf8),
            headers: [(field: "API-Key", value: credential.apiKey), (field: "API-Sign", value: signature),
                      (field: "Content-Type", value: "application/x-www-form-urlencoded; charset=utf-8")],
            session: session, errorType: KrakenAPIError.self, errorForResponse: hook
        )
    }

    // Every response counted against the request budget (AR69), then Kraken's refusals typed.
    private var hook: @Sendable (HTTPURLResponse, Data?) -> (any Error)? {
        { [tally, now] response, body in
            tally.note(at: now())
            return KrakenOHLCVClient.refusal(for: response, body: body)
        }
    }

    /// `API-Sign`: base64 of HMAC-SHA512, keyed with the decoded secret, over the path and SHA-256(nonce + body)
    package static func signature(path: String, nonce: String, body: String, secret: Data) -> String {
        let digest = SHA256.hash(data: Data((nonce + body).utf8))
        let message = Data(path.utf8) + Data(digest)
        let mac = HMAC<SHA512>.authenticationCode(for: message, using: SymmetricKey(data: secret))
        return Data(mac).base64EncodedString()
    }

    // The form body: each value escaped as a form value is.
    package static func formBody(_ fields: [(String, String)]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.1)" }.joined(separator: "&")
    }
}

struct KrakenPair: Sendable {
    let name: KrakenMarketName
    let base: Asset
    let quote: Asset
}

private actor KrakenClientState {
    private var pairs: [KrakenMarketName: KrakenPair] = [:]
    private var assets: [String: Asset] = [:]
    private var lastNonce: Int64 = 0

    func pair(_ name: KrakenMarketName) -> KrakenPair? { pairs[name] }
    func keep(_ pair: KrakenPair, as names: [KrakenMarketName]) { for name in names { pairs[name] = pair } }
    func asset(_ key: String) -> Asset? { assets[key] }
    func keep(_ asset: Asset, as key: String) { assets[key] = asset }

    func nextNonce(at milliseconds: Int64) -> Int64 {
        lastNonce = Swift.max(milliseconds, lastNonce + 1)
        return lastNonce
    }
}
