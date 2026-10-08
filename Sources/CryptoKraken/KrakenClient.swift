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

/// Kraken spot's exchange client (C31): its public and private REST, its signing, its errors as ``ExchangeClientError``
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
/// **Holdings.** Every call works in Kraken's declared holding constants (``KrakenHolding``); Kraken's names for them
/// reach them only through ``KrakenExchangeChain``'s table. The chain, the table and the holdings live in CryptoOHLCV,
/// not in this plug-in. At init the client has the chain add Kraken's declarations to its registry (and register the
/// chain), and configures itself into the chain's scanner. If the declarations cannot be added, init does not throw:
/// the error is kept and thrown by every call that needs a holding. The decimals Kraken states in its Assets answer are
/// checked against the declared holding's (AR45); a difference is refused (`AssetRegistryError.decimalsChanged`,
/// mapped to ``ExchangeClientError/refused(code:text:)``), never read past. A holding the table lacks or the registry
/// does not declare is refused the same way.
///
/// **Numbers.** Every number Kraken sends as text is decoded exactly, in the declared holding. Kraken spot has no
/// test market.
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
    private let registry: AssetRegistry
    // Kraken's declarations added to the registry at init, or why they could not be: thrown by every read that needs them
    private let declared: Result<Void, any Error>

    /// - Parameters:
    ///   - credential: The API key and its secret; `nil` for a client that only reads the markets and the books
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock: each private request's nonce is its milliseconds, kept increasing
    ///   - registry: The statement every amount and price is read against; Kraken's holdings are added to it here
    public init(
        credential: KrakenCredential?,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() },
        registry: AssetRegistry = .shared
    ) {
        self.credential = credential
        self.baseURL = Self.productionURL
        self.statusURL = URL(string: "https://status.kraken.com/api/v2/scheduled-maintenances/upcoming.json")!
        self.session = session
        self.now = now
        self.state = KrakenClientState()
        self.tally = RequestTally(window: Self.counterWindow)
        self.registry = registry
        self.declared = Result { try KrakenExchangeChain.declare(in: registry) }
        KrakenExchangeChain.default.scanner.configure(client: self)
    }

    /// Always `false`: Kraken spot has no test market
    public var hasTestMarket: Bool { false }

    // MARK: Markets and books

    /// Every pair of Kraken's AssetPairs, sorted by Kraken's key for it
    ///
    /// Each market's ``ExchangeClientMarket/alternateName`` is the pair's `altname` from AssetPairs ("XBTUSD" beside
    /// "XXBTZUSD"), `nil` where it is the same as the name. The base and quote are the declared holdings, `nil` where
    /// the table lacks the holding or the registry does not declare it (then the lot size and the minimum order are
    /// `nil` too); the symbols and decimals are Kraken's own, from Assets. The lot size is one unit at `lot_decimals`,
    /// and `leverageSet` is always `nil`.
    public func markets() async throws -> [ExchangeClientMarket<KrakenMarketName>] {
        do {
            let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [])
            var markets: [ExchangeClientMarket<KrakenMarketName>] = []
            for (key, info) in pairs.result.sorted(by: { $0.key < $1.key }) {
                let pair = try await self.pair(key: key, info: info)
                // Kraken's alternative name for the pair ("XBTUSD" beside "XXBTZUSD"), which it accepts as well; nil
                // where Kraken writes the two alike ("SOLUSD").
                let alternate = try KrakenMarketName(validating: info.altname)
                markets.append(ExchangeClientMarket(
                    name: pair.name, alternateName: alternate == pair.name ? nil : alternate,
                    baseSymbol: try AssetSymbol(validating: pair.baseEntry.altname), baseDecimals: pair.baseEntry.decimals,
                    quoteSymbol: try AssetSymbol(validating: pair.quoteEntry.altname), quoteDecimals: pair.quoteEntry.decimals,
                    base: pair.base, quote: pair.quote,
                    lotSize: try pair.base.map { try WireDecimal(digits: 1, fractionDigits: info.lotDecimals).amount(of: $0, in: registry) },
                    minimumOrder: try pair.base.map { try info.ordermin.amount(of: $0, in: registry) },
                    maxLeverage: info.leverageBuy.max(), leverageSet: nil, isPerpetual: false
                ))
            }
            return markets
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// The book from Kraken's ticker: its best bid and ask, their mid, and the last 24 hours' volume (`v[1]`) as the
    /// base volume. Kraken publishes no turnover in the quote asset, so the quote volume is the base volume priced at
    /// the mid, cut toward zero at the quote asset's base unit: the one figure here the exchange does not state itself.
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when AssetPairs or the Ticker lists no such market, or
    ///   when either of the pair's holdings is not a declared one
    public func orderBook(market: KrakenMarketName) async throws -> ExchangeClientBook<KrakenMarketName> {
        do {
            let pair = try await self.pair(market).declared()
            let ticker: KrakenResult<[String: KrakenTicker]> = try await publicGet("Ticker", [URLQueryItem(name: "pair", value: market.text)])
            guard let entry = ticker.result.first?.value else {
                throw ExchangeClientError.unknownMarket(market)
            }
            return ExchangeClientBook(
                market: market,
                mid: try WireDecimal.midpoint(entry.bid, entry.ask).price(of: pair.quote, per: pair.base, in: registry),
                bestBid: try entry.bid.price(of: pair.quote, per: pair.base, in: registry),
                bestAsk: try entry.ask.price(of: pair.quote, per: pair.base, in: registry),
                baseVolume: try entry.dayVolume.amount(of: pair.base, in: registry),
                // Kraken's ticker publishes no turnover in the quote, only the base volume (v) and its average price
                // (p): the quote volume is therefore the base volume priced at the mid, cut toward zero at the quote's
                // base unit. The road not taken: the base volume priced at Kraken's own day average, p[1].
                quoteVolume: try entry.dayVolume.times(WireDecimal.midpoint(entry.bid, entry.ask)).amountCutTowardZero(of: pair.quote, in: registry),
                readAt: now()
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    // MARK: Orders

    /// A limit order through AddOrder, then QueryOrders for what became of it
    ///
    /// `immediateOrCancel` sends `timeinforce=IOC` and `reduceOnly` sends `reduce_only=true`. The client order id is
    /// sent as AddOrder's `cl_ord_id` in Kraken's short UUID form, 32 lower-case hex digits; the open orders hand it
    /// back where Kraken states one. The `account` is not sent. The result is read from the queried order: nothing
    /// executed is `.cancelled` for a canceled or expired order, else `.resting`; the whole size executed is `.filled`,
    /// less is `.partlyFilled`, at the order's average `price`.
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` without a credential, and
    ///   ``ExchangeClientError/refused(code:text:)`` when the size or the limit is not in the market's assets, a
    ///   holding is not declared, or Kraken answers with no transaction id or does not know the order it took. An
    ///   `EOrder:` refusal of AddOrder is not thrown: it is returned as `.refused(code: "EOrder", text:)`.
    public func placeOrder(market: KrakenMarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                           immediateOrCancel: Bool, reduceOnly: Bool, clientOrderId: UInt128?, account: String) async throws -> ExchangeClientOrderResult<KrakenOrderId> {
        do {
            let pair = try await self.pair(market).declared()
            guard size.instance == pair.base, limit.base == pair.base, limit.quote == pair.quote else {
                throw ExchangeClientError.wrongAsset
            }
            var fields = [("ordertype", "limit"), ("type", side == .buy ? "buy" : "sell"), ("volume", try WireDecimal(size, in: registry).text),
                          ("pair", market.text), ("price", try WireDecimal(limit, in: registry).text)]
            if immediateOrCancel { fields.append(("timeinforce", "IOC")) }
            if reduceOnly { fields.append(("reduce_only", "true")) }
            if let clientOrderId { fields.append(("cl_ord_id", clientOrderId.clientOrderIdHex)) }

            let added: KrakenResult<KrakenAddedOrder>
            do {
                added = try await privatePost("AddOrder", fields)
            } catch let error as KrakenAPIError where error.messages.allSatisfy({ $0.hasPrefix("EOrder:") }) {
                let message = error.messages.first ?? "EOrder:"
                return .refused(code: "EOrder", text: String(message.dropFirst("EOrder:".count)))
            }
            guard let txid = added.result.txid.first else {
                throw ExchangeClientError.refused(code: nil, text: "Kraken answered the order with no transaction id")
            }
            let id = try KrakenOrderId(validating: txid)
            let queried: KrakenResult<[String: KrakenOrderInfo]> = try await privatePost("QueryOrders", [("txid", txid)])
            guard let order = queried.result[txid] else {
                throw ExchangeClientError.refused(code: nil, text: "Kraken does not know the order it took: \(txid)")
            }
            let executed = try order.volExec.amount(of: pair.base, in: registry)
            let time = order.closetm ?? order.opentm
            if executed.isZero {
                switch order.status {
                case "canceled", "expired": return .cancelled(id: id)
                default: return .resting(id: id, time: time)
                }
            }
            let price = try order.price.price(of: pair.quote, per: pair.base, in: registry)
            return executed == size
                ? .filled(units: executed, at: price, id: id, time: time)
                : .partlyFilled(units: executed, at: price, id: id, time: time)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    public func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<KrakenMarketName, KrakenOrderId>] {
        do {
            let open: KrakenResult<KrakenOpenOrders> = try await privatePost("OpenOrders", [])
            var orders: [ExchangeClientOpenOrder<KrakenMarketName, KrakenOrderId>] = []
            for (txid, order) in open.result.open.sorted(by: { $0.key < $1.key }) {
                let market = try KrakenMarketName(validating: order.descr.pair)
                let pair = try await self.pair(market).declared()
                orders.append(ExchangeClientOpenOrder(
                    id: try KrakenOrderId(validating: txid), market: market, side: order.descr.type == "buy" ? .buy : .sell,
                    units: try order.vol.amount(of: pair.base, in: registry) - order.volExec.amount(of: pair.base, in: registry),
                    clientOrderId: order.clOrdId.flatMap(UInt128.init(clientOrderIdText:))
                ))
            }
            return orders
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    public func cancelOrder(_ id: KrakenOrderId, market: KrakenMarketName, account: String) async throws {
        do {
            let cancelled: KrakenResult<KrakenCancelled> = try await privatePost("CancelOrder", [("txid", id.text)])
            guard cancelled.result.count > 0 else {
                throw ExchangeClientError.refused(code: nil, text: "Kraken cancelled no order for \(id.text)")
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    // MARK: The account

    /// The account's equivalent balance (`eb`) as `balance` and free margin (`mf`) as `withdrawable`, both in
    /// ``KrakenHolding/usd``, and its open margin positions
    ///
    /// The trade-balance call sends the holding's `wireName` as its `asset`. A position's units are its volume less
    /// the volume closed, and a fully closed one is left out; the entry price is its cost over its volume, the mark
    /// its value over its units, and the liquidation price is always `nil`. The mode is "spot".
    public func accountState(account: String) async throws -> ExchangeClientAccountState<KrakenMarketName> {
        do {
            let usd = try await holding(named: KrakenHolding.usd.wireName)
            let balance: KrakenResult<KrakenTradeBalance> = try await privatePost("TradeBalance", [("asset", KrakenHolding.usd.wireName)])
            let open: KrakenResult<[String: KrakenOpenPosition]> = try await privatePost("OpenPositions", [("docalcs", "true")])
            var positions: [ExchangeClientPosition<KrakenMarketName>] = []
            for (_, held) in open.result.sorted(by: { $0.key < $1.key }) {
                let market = try KrakenMarketName(validating: held.pair)
                let pair = try await self.pair(market).declared()
                let units = try held.vol.amount(of: pair.base, in: registry) - held.volClosed.amount(of: pair.base, in: registry)
                guard !units.isZero else { continue }
                positions.append(ExchangeClientPosition(
                    market: market, side: held.type == "buy" ? .buy : .sell, units: units,
                    entryPrice: try price(of: held.cost, per: held.vol, pair),
                    mark: try price(of: held.value, per: WireDecimal(units, in: registry), pair),
                    liquidationPrice: nil
                ))
            }
            return ExchangeClientAccountState(
                balance: try balance.result.eb.amount(of: usd, in: registry),
                withdrawable: try balance.result.mf.amount(of: usd, in: registry),
                positions: positions,
                mode: ExchangeClientAccountMode(name: "spot", allowsTransfer: false, allowsIsolatedMargin: false, alternatives: []),
                readAt: now()
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// The account's fills from TradesHistory and its deposits, withdrawals and transfers from Ledgers, oldest first
    ///
    /// The cursor names the oldest unmatched item, never a time alone: Kraken's `start` is exclusive, so the client
    /// sends it the ten-thousandth of a second before the cursor's instant to both calls, then hands up every item
    /// after the instant and those at the instant whose id the cursor does not name. Items of one instant come in the
    /// order of their ids, and each item's cursor names it and every item before it at its instant. Ledger kinds
    /// other than those three (a trade's own entry, margin, rollover, staking) are not handed up: a trade is its fill.
    /// A fill's position effect is the one the trade states: `close` where its `misc` notes say "closing", `open`
    /// where it carries a `posstatus` (present only on a trade that opened a position, whatever that position's
    /// status now), `nil` on a spot trade, which states none.
    public func ledgerItems(account: String, since: KrakenLedgerCursor?) async throws -> [ExchangeClientLedgerItem<KrakenMarketName, KrakenOrderId, KrakenLedgerCursor>] {
        do {
            let start = since.map { [("start", Self.startBefore($0.seconds))] } ?? []
            let trades: KrakenResult<KrakenTrades> = try await privatePost("TradesHistory", start)
            let ledger: KrakenResult<KrakenLedger> = try await privatePost("Ledgers", start)

            typealias Item = ExchangeClientLedgerItem<KrakenMarketName, KrakenOrderId, KrakenLedgerCursor>
            // Each item with its instant and its id; the cursor of each is made once the instant's items are known.
            var items: [(time: WireDecimal, id: KrakenLedgerId, make: (KrakenLedgerCursor) throws -> Item)] = []
            for (key, trade) in trades.result.trades {
                let id = try KrakenLedgerId(validating: key)
                let market = try KrakenMarketName(validating: trade.pair)
                let pair = try await self.pair(market).declared()
                let units = try trade.vol.amount(of: pair.base, in: registry)
                let price = try trade.price.price(of: pair.quote, per: pair.base, in: registry)
                let fee = try trade.fee.amount(of: pair.quote, in: registry)
                let order = try KrakenOrderId(validating: trade.ordertxid)
                items.append((trade.time, id, { cursor in
                    .fill(market: market, side: trade.type == "buy" ? .buy : .sell, units: units, price: price, fee: fee, order: order,
                          closedBy: nil, time: cursor.time, cursor: cursor, positionEffect: trade.positionEffect)
                }))
            }
            for (key, entry) in ledger.result.ledger {
                let id = try KrakenLedgerId(validating: key)
                switch entry.type {
                case "deposit":
                    let amount = try entry.amount.amount(of: try await holding(named: entry.asset), in: registry)
                    items.append((entry.time, id, { .deposit(amount, time: $0.time, cursor: $0) }))
                case "withdrawal":
                    let amount = try entry.amount.amount(of: try await holding(named: entry.asset), in: registry)
                    items.append((entry.time, id, { .withdrawal(amount, time: $0.time, cursor: $0) }))
                case "transfer":
                    let amount = try entry.amount.amount(of: try await holding(named: entry.asset), in: registry)
                    items.append((entry.time, id, { .internalMove(amount, from: entry.subtype, to: entry.asset, time: $0.time, cursor: $0) }))
                default:
                    // A trade's ledger entry is its fill, read from TradesHistory with its order; the other kinds (margin,
                    // rollover, staking…) have no case in C30 and are not handed up (a reading for the owner's pen).
                    continue
                }
            }

            items.sort { (Self.seconds($0.time), $0.id) < (Self.seconds($1.time), $1.id) }
            let resume = since.map { Self.seconds($0.seconds) }
            var result: [Item] = []
            var read: Set<KrakenLedgerId> = []
            var instant: Int128?
            for item in items {
                let at = Self.seconds(item.time)
                if at != instant {
                    instant = at
                    read = []
                }
                read.insert(item.id)
                if let since, let resume {
                    if at < resume || (at == resume && since.read.contains(item.id)) { continue }
                }
                result.append(try item.make(KrakenLedgerCursor(seconds: item.time, read: read)))
            }
            return result
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    // Kraken's `start` is exclusive: the cursor's instant less one ten-thousandth, which a read of it then includes.
    private static func startBefore(_ time: WireDecimal) -> String {
        let fourPlaces = time.fractionDigits <= 4
            ? time.digits * WireDecimal.powerOfTen(4 - time.fractionDigits)
            : time.digits / WireDecimal.powerOfTen(time.fractionDigits - 4)
        return WireDecimal(digits: max(0, fourPlaces - 1), fractionDigits: 4).text
    }

    // A cost over a volume, exactly: Kraken states a cost at the pair's cost decimals, which may be finer than the
    // quote asset's own, so both are scaled by the same power of ten until the cost fits, which leaves the ratio as it was.
    func price(of cost: WireDecimal, per volume: WireDecimal, _ pair: KrakenPair.Declared) throws -> Price {
        let quoteDecimals = try registry.decimals(of: pair.quote)
        let shift = max(0, cost.fractionDigits - quoteDecimals)
        let scaledCost = WireDecimal(digits: cost.digits, fractionDigits: cost.fractionDigits - shift)
        let scaledVolume = WireDecimal(digits: volume.digits * WireDecimal.powerOfTen(shift), fractionDigits: volume.fractionDigits)
        return try Price(try scaledCost.amount(of: pair.quote, in: registry), per: try scaledVolume.amount(of: pair.base, in: registry), in: registry)
    }

    private static func seconds(_ time: WireDecimal) -> Int128 {
        time.digits * WireDecimal.powerOfTen(10 - min(time.fractionDigits, 10))
    }

    /// Always throws `notOffered(member: "setLeverage")`: Kraken spot sets leverage on each order
    public func setLeverage(_ leverage: Int, market: KrakenMarketName, isolated: Bool, account: String) async throws {
        do {
            throw ExchangeClientError.leverageNotSettable
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// Always throws `notOffered(member: "transfer")`
    public func transfer(_ amount: Amount, from: String, to: String) async throws {
        do {
            throw ExchangeClientError.transferNotOffered
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// Kraken's REST API states nothing of a key's permissions: no endpoint answers what a key may do, who approved it
    /// or until when (a key's permissions are set and seen only on Kraken's site). So this always throws
    /// `notOffered(member: "keyFacts")` rather than guess them from what a request was allowed to do.
    public func keyFacts() async throws -> ExchangeClientKeyFacts {
        do {
            throw ExchangeClientError.keyFactsNotOffered
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// Kraken's REST call counter, Starter tier, counted by this client: at most 15, decaying 0.33 a second, so a
    /// full counter clears in 45 seconds; the client counts its own requests in 45-second windows
    public func requestBudget() async throws -> ExchangeClientRequestBudget {
        let reading = tally.reading(at: now())
        return ExchangeClientRequestBudget(limit: Self.counterLimit, remaining: max(0, Self.counterLimit - reading.count), resetsAt: reading.resetsAt)
    }

    static let counterLimit = 15
    static let counterWindow: Duration = .seconds(45)

    /// The upcoming maintenance Kraken schedules on its status page, each from its start to its end; every kind it
    /// posts. A maintenance with no start or end, or an end before its start, is left out.
    public func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow] {
        do {
            let page: KrakenStatusPage = try await ClientFetch.send(statusURL, session: session, errorType: KrakenAPIError.self, errorForResponse: { _, _ in nil })
            return page.scheduledMaintenances.compactMap { maintenance in
                guard let start = maintenance.start, let end = maintenance.end, start <= end else { return nil }
                return ExchangeClientMaintenanceWindow(subject: maintenance.subject, interval: DateInterval(start: start, end: end), text: maintenance.name ?? "")
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    /// A notice for each pair Kraken lists in a state other than "online", effective when read: Kraken states no date
    ///
    /// A "delisted" pair is a delisting, any other state a halt; the text is Kraken's status word.
    public func notices() async throws -> [ExchangeClientNotice<KrakenMarketName>] {
        do {
            let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [])
            let read = now()
            return try pairs.result.sorted(by: { $0.key < $1.key }).compactMap { key, info in
                guard info.status != "online" else { return nil }
                return ExchangeClientNotice(kind: info.status == "delisted" ? .delisting : .halt,
                                            market: try KrakenMarketName(validating: key), effectiveAt: read, text: info.status)
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.kraken)
        }
    }

    // MARK: The wire

    // A market's pair and holdings, asked of AssetPairs and Assets once and kept under both of Kraken's names for it.
    private func pair(_ market: KrakenMarketName) async throws -> KrakenPair {
        try declared.get()
        if let known = await state.pair(market) {
            return known
        }
        let pairs: KrakenResult<[String: KrakenPairInfo]> = try await publicGet("AssetPairs", [URLQueryItem(name: "pair", value: market.text)])
        guard let entry = pairs.result.first(where: { $0.key == market.text || $0.value.altname == market.text }) else {
            throw ExchangeClientError.unknownMarket(market)
        }
        return try await pair(key: entry.key, info: entry.value)
    }

    // A pair's two holdings through the table, each checked against the decimals Kraken states (AR45), and Kraken's
    // own names and decimals for them beside, as facts; a holding the table lacks or the statement does not declare is nil.
    private func pair(key: String, info: KrakenPairInfo) async throws -> KrakenPair {
        try declared.get()
        let baseEntry = try await entry(named: info.base)
        let quoteEntry = try await entry(named: info.quote)
        let pair = KrakenPair(
            name: try KrakenMarketName(validating: key),
            base: try KrakenExchangeChain.declaredInstance(wireName: info.base, decimals: baseEntry.decimals, in: registry),
            quote: try KrakenExchangeChain.declaredInstance(wireName: info.quote, decimals: quoteEntry.decimals, in: registry),
            baseEntry: baseEntry, quoteEntry: quoteEntry
        )
        await state.keep(pair, as: [pair.name, try KrakenMarketName(validating: info.altname)])
        return pair
    }

    // The declared holding Kraken names `name` ("ZUSD", "USD"), checked against the decimals Kraken states for it.
    private func holding(named name: String) async throws -> AssetInstance {
        try declared.get()
        guard let holding = try KrakenExchangeChain.declaredInstance(wireName: name, decimals: try await entry(named: name).decimals, in: registry) else {
            throw ExchangeClientError.unknownAsset(name)
        }
        return holding
    }

    // Kraken's Assets entry for a name, by its key ("XXBT") or its alternative name ("XBT"), asked of Assets once.
    private func entry(named name: String) async throws -> KrakenAssetEntry {
        if let known = await state.entry(name) {
            return known
        }
        let assets: KrakenResult<[String: KrakenAssetEntry]> = try await publicGet("Assets", [])
        await state.keep(assets.result)
        guard let entry = await state.entry(name) else {
            throw ExchangeClientError.unknownAsset(name)
        }
        return entry
    }

    private func publicGet<Value: Decodable & Sendable>(_ method: String, _ query: [URLQueryItem]) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent("0/public/\(method)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        return try await ClientFetch.send(components.url!, session: session, errorType: KrakenAPIError.self, errorForResponse: hook)
    }

    // A private request: the form body with its nonce first, signed (AR32).
    private func privatePost<Value: Decodable & Sendable>(_ method: String, _ fields: [(String, String)]) async throws -> Value {
        guard let credential else {
            throw ExchangeClientError.noCredential
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

// A pair with its two declared holdings, nil where undeclared, and Kraken's Assets entries for them.
struct KrakenPair: Sendable {
    let name: KrakenMarketName
    let base: AssetInstance?
    let quote: AssetInstance?
    let baseEntry: KrakenAssetEntry
    let quoteEntry: KrakenAssetEntry

    // A pair both of whose holdings are declared: the only kind a money value is made in.
    struct Declared: Sendable {
        let base: AssetInstance
        let quote: AssetInstance
    }

    func declared() throws -> Declared {
        guard let base else { throw ExchangeClientError.unknownAsset(baseEntry.altname) }
        guard let quote else { throw ExchangeClientError.unknownAsset(quoteEntry.altname) }
        return Declared(base: base, quote: quote)
    }
}

private actor KrakenClientState {
    private var pairs: [KrakenMarketName: KrakenPair] = [:]
    private var entries: [String: KrakenAssetEntry] = [:]
    private var lastNonce: Int64 = 0

    func pair(_ name: KrakenMarketName) -> KrakenPair? { pairs[name] }
    func keep(_ pair: KrakenPair, as names: [KrakenMarketName]) { for name in names { pairs[name] = pair } }
    // An entry by Kraken's key or its alternative name.
    func entry(_ name: String) -> KrakenAssetEntry? { entries[name] ?? entries.values.first { $0.altname == name } }
    func keep(_ answer: [String: KrakenAssetEntry]) { entries = answer }

    func nextNonce(at milliseconds: Int64) -> Int64 {
        lastNonce = Swift.max(milliseconds, lastNonce + 1)
        return lastNonce
    }
}
