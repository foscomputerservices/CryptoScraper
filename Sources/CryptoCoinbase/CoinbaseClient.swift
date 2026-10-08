// CoinbaseClient.swift
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

/// Coinbase Advanced Trade's exchange client (C31): its public and private REST, its signing, its errors as ``ExchangeClientError``
///
/// A private request carries a JWT made for it alone, signed ES256 with the CDP key: its subject and key id the key's
/// name, its issuer "cdp", valid for two minutes from now, its `uri` the request's method, host and path, with a
/// random nonce in the header. A signed call on a client made without a credential throws
/// ``ExchangeClientError/unauthorized(text:)``. Every request is one call of FOSFoundation's fetch; every call to
/// Coinbase's API, but not the status page, is counted against the request budget.
///
/// ```swift
/// let client = CoinbaseClient(credential: try CoinbaseCredential(keyName: name, privateKeyPEM: pem))
/// let btcusd = try CoinbaseMarketName(validating: "BTC-USD")
/// let book = try await client.orderBook(market: btcusd)
/// ```
///
/// **Accounts.** An account is a Coinbase portfolio's uuid. An order goes to the portfolio the key belongs to, so
/// the `account` an order member takes is not sent; ``transfer(_:from:to:)`` moves money between two portfolios.
///
/// **Holdings.** Every call works in Coinbase's declared holding constants (``CoinbaseHolding``); Coinbase's currency
/// ids reach them only through ``CoinbaseExchangeChain``'s table. The client adds Coinbase's declarations to its
/// registry at init, registers Coinbase's chain, and configures itself into the chain's scanner. A product's
/// increments are checked against the declared holdings' decimals (AR45): an increment finer than a holding counts is
/// refused, never read past. A currency the table lacks gives a market with a `nil` holding and refuses a money value.
/// The table, the holding constants and the chain live in CryptoOHLCV, not in this plug-in.
///
/// **Numbers.** Every number Coinbase sends as text is decoded exactly, in the declared holding; `base_increment` is
/// a market's `lotSize`, and `base_min_size` its `minimumOrder`. Coinbase's sandbox answers fixed responses and is no test market.
public struct CoinbaseClient: ExchangeClient {
    public typealias Credential = CoinbaseCredential
    public typealias MarketName = CoinbaseMarketName
    public typealias OrderId = CoinbaseOrderId
    public typealias Cursor = CoinbaseLedgerCursor

    private let credential: CoinbaseCredential?
    private let host = "api.coinbase.com"
    private let statusURL = URL(string: "https://status.coinbase.com/api/v2/scheduled-maintenances/upcoming.json")!
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let state: CoinbaseClientState
    private let tally: RequestTally
    private let registry: AssetRegistry
    // Coinbase's declarations added to the registry at init, or why they could not be: thrown by every read that needs them
    private let declared: Result<Void, any Error>

    /// - Parameters:
    ///   - credential: The CDP key; `nil` for a client that only reads the markets and the books
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock each JWT is made at
    ///   - registry: The statement every amount and price is read against; Coinbase's holdings are added to it here
    public init(
        credential: CoinbaseCredential?,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() },
        registry: AssetRegistry = .shared
    ) {
        self.credential = credential
        self.session = session
        self.now = now
        self.state = CoinbaseClientState()
        self.tally = RequestTally(window: Self.budgetWindow)
        self.registry = registry
        self.declared = Result { try CoinbaseExchangeChain.declare(in: registry) }
        CoinbaseExchangeChain.default.scanner.configure(client: self)
    }

    public var hasTestMarket: Bool { false }

    // MARK: Markets and books

    /// Every product Coinbase lists, each with its holdings resolved through ``CoinbaseExchangeChain``'s table
    ///
    /// A product whose currency the table lacks, or the statement does not declare, comes with a `nil` base or quote
    /// and a `nil` lot size and minimum order. A currency the table lacks is no error here.
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when an increment is finer than the declared holding's
    ///   decimals
    public func markets() async throws -> [ExchangeClientMarket<CoinbaseMarketName>] {
        do {
            try declared.get()
            let listed: CoinbaseProducts = try await send("GET", "/api/v3/brokerage/market/products", signed: false)
            return try listed.products.map { product in
                let pair = try product.holdings(in: registry)
                // Coinbase states no decimals for a currency: the precision it states, each increment's places, is
                // handed up as the fact. Its alias (BTC-USD's "BTC-USDC") settles in another holding, so it is not
                // the market's second name.
                return ExchangeClientMarket(
                    name: try CoinbaseMarketName(validating: product.productId), alternateName: nil,
                    baseSymbol: try AssetSymbol(validating: pair.baseName), baseDecimals: product.baseIncrement.fractionDigits,
                    quoteSymbol: try AssetSymbol(validating: pair.quoteName), quoteDecimals: product.quoteIncrement.fractionDigits,
                    base: pair.base, quote: pair.quote,
                    lotSize: try pair.base.map { try product.baseIncrement.amount(of: $0, in: registry) },
                    minimumOrder: try pair.base.map { try product.baseMinSize.amount(of: $0, in: registry) },
                    maxLeverage: product.maxLeverage, leverageSet: nil, isPerpetual: product.isPerpetual
                )
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// The book from Coinbase's product book and product: the best bid and ask, Coinbase's mid, `volume_24h` as the
    /// base volume, and `approximate_quote_24h_volume` as the quote volume, cut toward zero at the quote asset's base
    /// unit. Where Coinbase writes that turnover as "", it publishes no quote figure, and the quote volume is the base
    /// volume priced at the mid. The read time is the book's own time, or now where Coinbase's time does not parse.
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when a side of the book is empty, when Coinbase states
    ///   no day's volume, or when a currency of the product is no declared holding
    public func orderBook(market: CoinbaseMarketName) async throws -> ExchangeClientBook<CoinbaseMarketName> {
        do {
            let product = try await self.product(market)
            let pair = try product.holdings(in: registry).declared()
            let book: CoinbaseProductBook = try await send("GET", "/api/v3/brokerage/market/product_book",
                                                           query: [URLQueryItem(name: "product_id", value: market.text), URLQueryItem(name: "limit", value: "1")], signed: false)
            guard let bid = book.pricebook.bids.first?.price, let ask = book.pricebook.asks.first?.price else {
                throw ExchangeClientError.refused(code: nil, text: "The book of \(market.text) is empty on a side")
            }
            guard let volume = product.volume24h else {
                throw ExchangeClientError.refused(code: nil, text: "Coinbase states no day's volume for \(market.text)")
            }
            // Coinbase's own turnover, approximate_quote_24h_volume, where it states one; where it writes "" the
            // base volume priced at the mid stands in. Either is cut toward zero at the quote asset's base unit.
            let turnover = try product.quoteVolume24h ?? volume.times(book.midMarket)
            return ExchangeClientBook(
                market: market,
                mid: try book.midMarket.price(of: pair.quote, per: pair.base, in: registry),
                bestBid: try bid.price(of: pair.quote, per: pair.base, in: registry),
                bestAsk: try ask.price(of: pair.quote, per: pair.base, in: registry),
                baseVolume: try volume.amount(of: pair.base, in: registry),
                quoteVolume: try turnover.amountCutTowardZero(of: pair.quote, in: registry),
                readAt: CoinbaseTime.date(book.pricebook.time) ?? now()
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    // MARK: Orders

    /// Reduce-only is not sent for a spot product, which holds no position to reduce. The client order id is sent as
    /// `client_order_id` in a UUID's form; Coinbase requires one, so with none given the client sends a fresh UUID.
    /// An immediate-or-cancel order is sent as Coinbase's `sor_limit_ioc`, any other as a `limit_limit_gtc` that is
    /// not post-only. The order is read back once after it is created, and its status and fill give the result.
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when `size` or `limit` is in an asset other than the
    ///   product's
    public func placeOrder(market: CoinbaseMarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                           immediateOrCancel: Bool, reduceOnly: Bool, clientOrderId: UInt128?, account: String) async throws -> ExchangeClientOrderResult<CoinbaseOrderId> {
        do {
            let pair = try await self.product(market).holdings(in: registry).declared()
            guard size.instance == pair.base, limit.base == pair.base, limit.quote == pair.quote else {
                throw ExchangeClientError.wrongAsset
            }
            let sizeText = try WireDecimal(size, in: registry).text
            let limitText = try WireDecimal(limit, in: registry).text
            let configuration = immediateOrCancel
                ? #"{"sor_limit_ioc":{"base_size":"\#(sizeText)","limit_price":"\#(limitText)"}}"#
                : #"{"limit_limit_gtc":{"base_size":"\#(sizeText)","limit_price":"\#(limitText)","post_only":false}}"#
            let body = #"{"client_order_id":"\#(clientOrderId?.clientOrderIdUUIDText ?? UUID().uuidString.lowercased())","product_id":"\#(market.text)","side":"\#(side == .buy ? "BUY" : "SELL")","order_configuration":\#(configuration)}"#
            let created: CoinbaseCreatedOrder = try await send("POST", "/api/v3/brokerage/orders", body: body)
            guard created.success, let orderId = created.successResponse?.orderId else {
                return .refused(code: created.errorResponse?.error ?? "", text: created.errorResponse?.message ?? "")
            }
            let id = try CoinbaseOrderId(validating: orderId)
            let read: CoinbaseOrderEnvelope = try await send("GET", "/api/v3/brokerage/orders/historical/\(orderId)")
            let order = read.order
            let filled = try order.filledSize.amount(of: pair.base, in: registry)
            let time = order.lastFillTime.flatMap(CoinbaseTime.date) ?? now()
            if filled.isZero {
                switch order.status {
                case "CANCELLED", "EXPIRED": return .cancelled(id: id)
                case "FAILED": return .refused(code: order.status, text: order.rejectMessage ?? "")
                default: return .resting(id: id, time: time)
                }
            }
            let price = try order.averageFilledPrice.price(of: pair.quote, per: pair.base, in: registry)
            return filled == size ? .filled(units: filled, at: price, id: id, time: time) : .partlyFilled(units: filled, at: price, id: id, time: time)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// The orders Coinbase lists as `OPEN`, each with its unfilled size; `account` is not sent
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when an order states no base size
    public func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<CoinbaseMarketName, CoinbaseOrderId>] {
        do {
            let listed: CoinbaseOrders = try await send("GET", "/api/v3/brokerage/orders/historical/batch", query: [URLQueryItem(name: "order_status", value: "OPEN")])
            var open: [ExchangeClientOpenOrder<CoinbaseMarketName, CoinbaseOrderId>] = []
            for order in listed.orders {
                let market = try CoinbaseMarketName(validating: order.productId)
                let pair = try await self.product(market).holdings(in: registry).declared()
                guard let size = order.baseSize else {
                    throw ExchangeClientError.refused(code: nil, text: "Coinbase states no base size for order \(order.orderId)")
                }
                open.append(ExchangeClientOpenOrder(id: try CoinbaseOrderId(validating: order.orderId), market: market, side: order.side == "BUY" ? .buy : .sell,
                                                    units: try size.amount(of: pair.base, in: registry) - order.filledSize.amount(of: pair.base, in: registry),
                                                    clientOrderId: order.clientOrderId.flatMap(UInt128.init(clientOrderIdText:))))
            }
            return open
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// Cancels one order by a batch cancel of its id; `market` and `account` are not sent
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` with Coinbase's failure reason when the cancel is not a success
    public func cancelOrder(_ id: CoinbaseOrderId, market: CoinbaseMarketName, account: String) async throws {
        do {
            let answer: CoinbaseCancelResults = try await send("POST", "/api/v3/brokerage/orders/batch_cancel", body: #"{"order_ids":["\#(id.text)"]}"#)
            guard let result = answer.results.first, result.success else {
                let reason = answer.results.first?.failureReason
                throw ExchangeClientError.refused(code: reason, text: reason ?? "Coinbase answered the cancel with no result")
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    // MARK: The account

    /// The key's portfolio's USD wallet: its available and held money as the balance, its available money as what can
    /// be withdrawn; a spot portfolio holds no positions. The mode is the key's portfolio type. Coinbase's account
    /// reads answer for the key's own portfolio alone, so `account` must be that portfolio's uuid, as Coinbase's
    /// key permissions state it; another portfolio is refused, naming both, never answered with the key's own.
    public func accountState(account: String) async throws -> ExchangeClientAccountState<CoinbaseMarketName> {
        do {
            try declared.get()
            let permissions: CoinbaseKeyPermissions = try await send("GET", "/api/v3/brokerage/key_permissions")
            guard account == permissions.portfolioUuid else {
                throw ExchangeClientError.notTheKeysPortfolio(account, keys: permissions.portfolioUuid)
            }
            var wallets: [CoinbaseAccount] = []
            var cursor: String?
            repeat {
                var query = [URLQueryItem(name: "limit", value: "250")]
                if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
                let page: CoinbaseAccounts = try await send("GET", "/api/v3/brokerage/accounts", query: query)
                wallets += page.accounts
                // The next page, until Coinbase says there is none or hands back the cursor it was just given.
                cursor = page.hasNext && page.cursor != cursor ? page.cursor : nil
            } while cursor != nil

            // The dollar's wallet: the one whose currency the table names Coinbase's USD.
            let usd = AssetInstance(CoinbaseHolding.usd)
            let wallet = wallets.first { (try? CoinbaseExchangeChain.default.contract(for: $0.currency)) == CoinbaseHolding.usd }
            let available = try wallet?.availableBalance.value.amount(of: usd, in: registry) ?? .zero(of: usd)
            let held = try wallet?.hold?.value.amount(of: usd, in: registry) ?? .zero(of: usd)
            return ExchangeClientAccountState(
                balance: available + held, withdrawable: available, positions: [],
                mode: ExchangeClientAccountMode(name: permissions.portfolioType, allowsTransfer: permissions.canTransfer, allowsIsolatedMargin: false, alternatives: []),
                readAt: now()
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// The portfolio's fills since the cursor, each with its commission; Advanced Trade states no deposit, withdrawal
    /// or funding among them, oldest first by the cursor's time. The cursor names the oldest unmatched fill, never a
    /// time alone: List Fills includes the fill at its start, and the client hands up the fills after the cursor's time
    /// plus those at it whose trade id the cursor does not name. Fills of one time come in the order of their trade
    /// ids, each fill's cursor names it and every fill before it at its time, and a fill a repeated page repeats is
    /// handed up once. A read is every page Coinbase hands back. `account`
    /// is not sent. A fill's position effect is `nil`: List Fills states none (its side is buy or sell, nothing that
    /// opens or closes a position).
    public func ledgerItems(account: String, since: CoinbaseLedgerCursor?) async throws -> [ExchangeClientLedgerItem<CoinbaseMarketName, CoinbaseOrderId, CoinbaseLedgerCursor>] {
        do {
            try declared.get()
            var fills: [CoinbaseFill] = []
            var cursor: String?
            repeat {
                var query = [URLQueryItem(name: "limit", value: "100")]
                if let since { query.append(URLQueryItem(name: "start_sequence_timestamp", value: since.sequenceTimestamp)) }
                if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
                let page: CoinbaseFills = try await send("GET", "/api/v3/brokerage/orders/historical/fills", query: query)
                fills += page.fills
                // The next page, until a page is empty, carries no cursor, or hands back the cursor it was just given.
                let next = page.cursor.flatMap { $0.isEmpty || page.fills.isEmpty ? nil : $0 }
                cursor = next != cursor ? next : nil
            } while cursor != nil

            // Each fill once, by its trade id, in the order of its time and then its trade id.
            var seen: Set<CoinbaseTradeId> = []
            var keyed: [(time: Date, id: CoinbaseTradeId, fill: CoinbaseFill)] = []
            for fill in fills {
                let id = try CoinbaseTradeId(validating: fill.tradeId)
                guard seen.insert(id).inserted else { continue }
                keyed.append((try CoinbaseLedgerCursor(sequenceTimestamp: fill.sequenceTimestamp).time, id, fill))
            }
            keyed.sort { ($0.time, $0.id) < ($1.time, $1.id) }

            var items: [ExchangeClientLedgerItem<CoinbaseMarketName, CoinbaseOrderId, CoinbaseLedgerCursor>] = []
            var read: Set<CoinbaseTradeId> = []
            var instant: Date?
            for (at, id, fill) in keyed {
                if at != instant {
                    instant = at
                    read = []
                }
                read.insert(id)
                if let since, at < since.time || (at == since.time && since.read.contains(id)) { continue }
                let market = try CoinbaseMarketName(validating: fill.productId)
                let pair = try await self.product(market).holdings(in: registry).declared()
                let cursor = try CoinbaseLedgerCursor(sequenceTimestamp: fill.sequenceTimestamp, read: read)
                let time = CoinbaseTime.date(fill.tradeTime) ?? cursor.time
                items.append(.fill(
                    market: market, side: fill.side == "BUY" ? .buy : .sell, units: try fill.size.amount(of: pair.base, in: registry),
                    price: try fill.price.price(of: pair.quote, per: pair.base, in: registry), fee: try fill.commission.amount(of: pair.quote, in: registry),
                    order: try CoinbaseOrderId(validating: fill.orderId), closedBy: nil, time: time, cursor: cursor
                ))
            }
            return items
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// Always throws ``ExchangeClientError/notOffered(member:)``: Coinbase Advanced Trade sets no leverage
    public func setLeverage(_ leverage: Int, market: CoinbaseMarketName, isolated: Bool, account: String) async throws {
        do {
            throw ExchangeClientError.leverageNotSettable
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// Moves `amount` from one portfolio to another, both named by their uuid; the currency is sent as the holding's
    /// `wireName`
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when `amount` is not in a declared Coinbase holding
    public func transfer(_ amount: Amount, from: String, to: String) async throws {
        do {
            // The currency is the holding's wire name, the one Coinbase accepts: only a declared Coinbase holding moves.
            try declared.get()
            guard amount.instance.chainId == CoinbaseExchangeChain.default.id, let key = amount.instance.address,
                  (try? registry.decimals(of: amount.instance)) != nil else {
                throw ExchangeClientError.wrongAsset
            }
            let currency = CoinbaseHolding(address: key).wireName
            let value = try WireDecimal(amount, in: registry).text
            let body = #"{"funds":{"value":"\#(value)","currency":"\#(currency)"},"source_portfolio_uuid":"\#(Self.escaped(from))","target_portfolio_uuid":"\#(Self.escaped(to))"}"#
            let _: CoinbaseMovedFunds = try await send("POST", "/api/v3/brokerage/portfolios/move_funds", body: body)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// Coinbase's own statement of the key: its trade and transfer permissions; Coinbase's transfer permission is the
    /// one that also sends money out, so it is the withdrawal's too. Coinbase states no approval or expiry.
    public func keyFacts() async throws -> ExchangeClientKeyFacts {
        do {
            let permissions: CoinbaseKeyPermissions = try await send("GET", "/api/v3/brokerage/key_permissions")
            return ExchangeClientKeyFacts(canTrade: permissions.canTrade, canTransfer: permissions.canTransfer, canWithdraw: permissions.canTransfer,
                                          approvedBy: nil, validUntil: nil)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// The limit Coinbase publishes for a key, 10,000 requests an hour, against this client's own count of its
    /// requests in the hour; every Coinbase API response is counted, the status page's is not
    public func requestBudget() async throws -> ExchangeClientRequestBudget {
        let reading = tally.reading(at: now())
        return ExchangeClientRequestBudget(limit: Self.budgetLimit, remaining: max(0, Self.budgetLimit - reading.count), resetsAt: reading.resetsAt)
    }

    static let budgetLimit = 10_000
    static let budgetWindow: Duration = .seconds(3_600)

    /// The maintenance Coinbase schedules on its status page, each from its start to its end; a maintenance with a
    /// missing or unparseable time, or an end before its start, is left out
    public func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow] {
        do {
            let page: CoinbaseStatusPage = try await ClientFetch.send(statusURL, session: session, errorType: CoinbaseAPIError.self, errorForResponse: { _, _ in nil })
            return page.scheduledMaintenances.compactMap { maintenance in
                guard let start = maintenance.scheduledFor.flatMap(CoinbaseTime.date), let end = maintenance.scheduledUntil.flatMap(CoinbaseTime.date), start <= end else {
                    return nil
                }
                return ExchangeClientMaintenanceWindow(subject: maintenance.subject, interval: DateInterval(start: start, end: end), text: maintenance.name ?? "")
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    /// A notice for each product Coinbase lists as delisted (a `.delisting`) or carrying a restriction flag
    /// (`trading_disabled`, `is_disabled`, `cancel_only`, `limit_only` or `post_only`, a `.halt` naming the first),
    /// effective when read
    public func notices() async throws -> [ExchangeClientNotice<CoinbaseMarketName>] {
        do {
            let listed: CoinbaseProducts = try await send("GET", "/api/v3/brokerage/market/products", signed: false)
            let read = now()
            return try listed.products.compactMap { product in
                let market = try CoinbaseMarketName(validating: product.productId)
                if product.status == "delisted" {
                    return ExchangeClientNotice(kind: .delisting, market: market, effectiveAt: read, text: product.status)
                }
                guard let restriction = product.restriction else { return nil }
                return ExchangeClientNotice(kind: .halt, market: market, effectiveAt: read, text: restriction)
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.coinbase)
        }
    }

    // MARK: The wire

    private func product(_ market: CoinbaseMarketName) async throws -> CoinbaseProduct {
        try declared.get()
        if let known = await state.product(market) {
            return known
        }
        let product: CoinbaseProduct = try await send("GET", "/api/v3/brokerage/market/products/\(market.text)", signed: false)
        await state.keep(product, as: market)
        return product
    }

    private func send<Value: Decodable & Sendable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: String? = nil, signed: Bool = true) async throws -> Value {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        var headers: [(field: String, value: String)] = []
        if signed {
            guard let credential else {
                throw ExchangeClientError.noCredential
            }
            headers.append((field: "Authorization", value: "Bearer " + (try Self.jwt(credential, uri: "\(method) \(host)\(path)", at: now()))))
        }
        return try await ClientFetch.send(
            components.url!, method: method, body: body.map { Data($0.utf8) }, headers: headers,
            session: session, errorType: CoinbaseAPIError.self, errorForResponse: hook
        )
    }

    // Every response counted against the request budget (AR69), then Coinbase's limit typed.
    private var hook: @Sendable (HTTPURLResponse, Data?) -> (any Error)? {
        { [tally, now] response, body in
            tally.note(at: now())
            return CoinbaseOHLCVClient.limitError(for: response, body: body)
        }
    }

    /// The JWT for one request: ES256 over the base64url header and claims, as Coinbase's authentication guide makes it
    ///
    /// The header carries the key name as `kid` and a fresh random nonce; the claims are `sub`, `iss` ("cdp"), `nbf`
    /// at `time` and `exp` 120 seconds after it, and `uri`.
    ///
    /// - Throws: what the P-256 signing throws
    package static func jwt(_ credential: CoinbaseCredential, uri: String, at time: Date) throws -> String {
        let seconds = Int64(time.timeIntervalSince1970)
        let nonce = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        let header = #"{"alg":"ES256","kid":"\#(escaped(credential.keyName))","nonce":"\#(nonce)","typ":"JWT"}"#
        let claims = #"{"sub":"\#(escaped(credential.keyName))","iss":"cdp","nbf":\#(seconds),"exp":\#(seconds + 120),"uri":"\#(escaped(uri))"}"#
        let signingInput = base64URL(Data(header.utf8)) + "." + base64URL(Data(claims.utf8))
        let signature = try credential.key.signature(for: Data(signingInput.utf8))
        return signingInput + "." + base64URL(signature.rawRepresentation)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private actor CoinbaseClientState {
    private var products: [CoinbaseMarketName: CoinbaseProduct] = [:]

    func product(_ market: CoinbaseMarketName) -> CoinbaseProduct? { products[market] }
    func keep(_ product: CoinbaseProduct, as market: CoinbaseMarketName) { products[market] = product }
}
