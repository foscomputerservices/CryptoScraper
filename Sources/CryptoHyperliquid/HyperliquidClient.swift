// HyperliquidClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import CryptoSwift
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Hyperliquid's exchange client (C31): its info and exchange endpoints, its signing, its errors as ``ExchangeClientError``
///
/// Every order, cancel, leverage change and sub-account transfer is an action signed by the agent key (AR33); the
/// main wallet is found by asking Hyperliquid whose agent the key is. Reads go to the info endpoint and need no
/// signature. Every request is one call of FOSFoundation's fetch.
///
/// ```swift
/// let client = HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket)
/// let btc = try HyperliquidMarketName(validating: "BTC")
/// let book = try await client.orderBook(market: btc)
/// let placed = try await client.placeOrder(market: btc, side: .buy, size: size, limit: limit,
///                                          immediateOrCancel: true, reduceOnly: false, clientOrderId: token, account: "four-hour-2x")
/// ```
///
/// **Accounts.** An account is Hyperliquid's own name for it: a sub-account's name as the main wallet lists it
/// ("four-hour-2x"), or an address ("0x…" and 20 bytes of hex), the main wallet's own included. A name the main
/// wallet's list lacks is refused as an unknown account. An action for the main wallet's own account is signed
/// without a vault address; one for a sub-account names the sub-account's address.
///
/// **Holdings.** Every call works in Hyperliquid's declared holding constants (``HyperliquidHolding``); Hyperliquid's
/// names for them reach them only through ``HyperliquidExchangeChain``'s table. The chain, the table and the holdings
/// live in CryptoOHLCV, not in this plug-in. The client adds the chain's declarations to its registry at init,
/// registers Hyperliquid's chain, and configures itself into the chain's scanner; if the declarations cannot be added,
/// the failure is kept and every read that needs them throws it, mapped to ``ExchangeClientError``. The size decimals
/// Hyperliquid states in its `meta` are checked against the declared holding's (AR45); a difference is refused for the
/// whole `meta` read, never read past. A coin the table lacks, or whose holding is not declared, is listed by
/// ``markets()`` with a `nil` base and refuses a money value: a book, an order, an open order, a held position or a
/// fill in that coin refuses the call, so an undeclared holding in an account refuses the read of that account.
///
/// **Numbers.** A market's base is its coin's holding at the coin's size decimals, so one lot is one base unit; its
/// quote is ``HyperliquidHolding/usdc`` at six decimals, Hyperliquid's unit of account, in which its $10 minimum order
/// is stated. Every number Hyperliquid sends as text is decoded exactly but two, each cut toward zero: a funding rate finer than nine digits at a ``Fraction``'s
/// nine, and a book's day turnover finer than USDC's six at six. A book's two volumes are Hyperliquid's own two
/// statements of the day: `dayBaseVlm`, the base asset traded, and `dayNtlVlm`, the turnover in USDC (stated to ten
/// digits, BTC's "1994433.2905599999" on the test market, so cut toward zero at six).
public struct HyperliquidClient: ExchangeClient {
    public typealias Credential = HyperliquidCredential
    public typealias MarketName = HyperliquidMarketName
    public typealias OrderId = HyperliquidOrderId
    public typealias Cursor = HyperliquidLedgerCursor

    private let credential: HyperliquidCredential?
    private let endpoint: HyperliquidEndpoint
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let state: HyperliquidClientState
    private let registry: AssetRegistry
    // Hyperliquid's declarations added to the registry at init, or why they could not be: thrown by every read that needs them
    private let declared: Result<Void, any Error>
    // Hyperliquid's unit of account, the declared holding every account's money is counted in
    private let usdc = AssetInstance(HyperliquidHolding.usdc)

    /// - Parameters:
    ///   - credential: The agent key that signs; `nil` for a client that only reads the markets and the books
    ///   - endpoint: The test market or production
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock: each signed action's nonce is its milliseconds, kept increasing
    ///   - registry: The statement every amount and price is read against; Hyperliquid's holdings are added to it here
    public init(
        credential: HyperliquidCredential?,
        endpoint: HyperliquidEndpoint,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() },
        registry: AssetRegistry = .shared
    ) {
        self.credential = credential
        self.endpoint = endpoint
        self.session = session
        self.now = now
        self.state = HyperliquidClientState()
        self.registry = registry
        self.declared = Result { try HyperliquidExchangeChain.declare(in: registry) }
        HyperliquidExchangeChain.default.scanner.configure(client: self)
    }

    public var hasTestMarket: Bool { true }

    // MARK: Markets and books

    /// Hyperliquid's listed perpetuals, the delisted left out, read fresh from `meta` each call
    ///
    /// `markets()` names no account, so each market's `leverageSet` is read from the main wallet's clearinghouseState:
    /// the leverage on each coin the main wallet holds a position in, `nil` for a coin with no position, and `nil`
    /// throughout for a client made without a credential, which has no wallet to read. A market's `base` and `lotSize`
    /// are `nil` where its coin's holding is not declared; its `minimumOrder` is $10 in USDC regardless.
    public func markets() async throws -> [ExchangeClientMarket<HyperliquidMarketName>] {
        do {
            let meta = try await perpMeta(refresh: true)
            let quoteDecimals = try registry.decimals(of: usdc)
            let leverage = try await leverageSet()
            var markets: [ExchangeClientMarket<HyperliquidMarketName>] = []
            for listed in meta.universe where listed.isDelisted != true {
                let name = try HyperliquidMarketName(validating: listed.name)
                let coin = try await self.coin(name)
                // Hyperliquid has one name for a market, its coin's, so there is no second one. Its minimum order is
                // $10 in its USDC, a declared holding, so it is stated even where the base is not declared.
                markets.append(ExchangeClientMarket(
                    name: name, alternateName: nil,
                    baseSymbol: try AssetSymbol(validating: listed.name), baseDecimals: listed.szDecimals,
                    quoteSymbol: try AssetSymbol(validating: HyperliquidHolding.usdc.wireName), quoteDecimals: quoteDecimals,
                    base: coin.base, quote: usdc,
                    lotSize: coin.base.map { Amount(baseUnits: 1, of: $0) },
                    minimumOrder: try Amount(whole: 10, of: usdc, in: registry),
                    maxLeverage: listed.maxLeverage, leverageSet: leverage[listed.name], isPerpetual: true
                ))
            }
            return markets
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// The best bid and ask of `market`, its mid (Hyperliquid's `midPx`, else the midpoint of the two), and the day's
    /// two volumes; `readAt` is the book's own time
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` for a book empty on a side, a market Hyperliquid lists
    ///   no context for, or a coin whose holding is not declared
    public func orderBook(market: HyperliquidMarketName) async throws -> ExchangeClientBook<HyperliquidMarketName> {
        do {
            let base = try await self.coin(market).declared()
            let book: HyperliquidL2Book = try await info(.map([("type", .string("l2Book")), ("coin", .string(market.text))]))
            let contexts: HyperliquidMetaAndContexts = try await info(.map([("type", .string("metaAndAssetCtxs"))]))
            guard let bid = book.levels.first?.first?.px, let ask = book.levels.last?.first?.px, book.levels.count == 2 else {
                throw ExchangeClientError.refused(code: nil, text: "The book of \(market.text) is empty on a side")
            }
            guard let context = contexts.context(of: market.text) else {
                throw ExchangeClientError.unknownMarket(market)
            }
            let mid = context.midPx ?? WireDecimal.midpoint(bid, ask)
            return ExchangeClientBook(
                market: market,
                mid: try mid.price(of: usdc, per: base, in: registry),
                bestBid: try bid.price(of: usdc, per: base, in: registry),
                bestAsk: try ask.price(of: usdc, per: base, in: registry),
                baseVolume: try context.dayBaseVlm.amount(of: base, in: registry),
                quoteVolume: try context.dayNtlVlm.amountCutTowardZero(of: usdc, in: registry),
                readAt: Date(wireMilliseconds: book.time)
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // MARK: Orders

    /// Places one limit order, signed by the agent key, for `account`
    ///
    /// Hyperliquid's order answer states no time, so a filled, partly filled or resting result's `time` is this
    /// client's clock (`now`) when the answer arrived, never the exchange's; the fill's own time is the ledger's.
    /// The client order id is sent as the order's `cloid`, "0x" and its 16 bytes in 32 hex digits.
    ///
    /// `size` must be in the market's base and `limit` a price of USDC per that base. A fill of the whole `size` is
    /// `.filled`, any other filled size `.partlyFilled`. An immediate-or-cancel order Hyperliquid could not match
    /// at once is `.cancelledBeforeAccepted`; any other status Hyperliquid words as an error is returned as
    /// `.refused(code: "order", text:)`, not thrown.
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when `size` or `limit` is in another asset than the
    ///   market's or Hyperliquid's answer has no status; ``ExchangeClientError/unauthorized(text:)`` without a credential
    public func placeOrder(market: HyperliquidMarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                           immediateOrCancel: Bool, reduceOnly: Bool, clientOrderId: UInt128?, account: String) async throws -> ExchangeClientOrderResult<HyperliquidOrderId> {
        do {
            let coin = try await self.coin(market)
            let base = try coin.declared()
            guard size.instance == base, limit.base == base, limit.quote == usdc else {
                throw ExchangeClientError.wrongAsset
            }
            let action = HyperliquidActions.order(asset: coin.index, isBuy: side == .buy, limit: try WireDecimal(limit, in: registry).text,
                                                  size: try WireDecimal(size, in: registry).text, reduceOnly: reduceOnly,
                                                  timeInForce: immediateOrCancel ? "Ioc" : "Gtc",
                                                  cloid: clientOrderId.map { "0x" + $0.clientOrderIdHex })
            let answer: HyperliquidExchangeAnswer<HyperliquidOrderStatuses> = try await exchange(action, vault: try await vault(for: account))
            guard let status = answer.response.data?.statuses.first else {
                throw ExchangeClientError.refused(code: nil, text: "Hyperliquid answered the order with no status")
            }
            // The client's clock: Hyperliquid's answer states no time.
            let time = now()
            switch status {
            case .filled(let totalSize, let averagePrice, let oid):
                let units = try totalSize.amount(of: base, in: registry)
                let price = try averagePrice.price(of: usdc, per: base, in: registry)
                return units == size
                    ? .filled(units: units, at: price, id: HyperliquidOrderId(oid), time: time)
                    : .partlyFilled(units: units, at: price, id: HyperliquidOrderId(oid), time: time)
            case .resting(let oid):
                return .resting(id: HyperliquidOrderId(oid), time: time)
            case .error(let text) where immediateOrCancel && text.hasPrefix("Order could not immediately match"):
                return .cancelledBeforeAccepted
            case .error(let text):
                return .refused(code: "order", text: text)
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// The resting orders of `account`, with their `cloid` read back as the client order id where one was sent
    public func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<HyperliquidMarketName, HyperliquidOrderId>] {
        do {
            let address = try await self.address(of: account)
            let orders: [HyperliquidOpenOrder] = try await info(.map([("type", .string("openOrders")), ("user", .string(address))]))
            var open: [ExchangeClientOpenOrder<HyperliquidMarketName, HyperliquidOrderId>] = []
            for order in orders {
                let market = try HyperliquidMarketName(validating: order.coin)
                let base = try await self.coin(market).declared()
                open.append(ExchangeClientOpenOrder(id: HyperliquidOrderId(order.oid), market: market,
                                                    side: order.side == "B" ? .buy : .sell, units: try order.sz.amount(of: base, in: registry),
                                                    clientOrderId: order.cloid.flatMap(UInt128.init(clientOrderIdText:))))
            }
            return open
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// Cancels the resting order `id` on `market` for `account`
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` with Hyperliquid's words when its cancel status is an error
    public func cancelOrder(_ id: HyperliquidOrderId, market: HyperliquidMarketName, account: String) async throws {
        do {
            let coin = try await self.coin(market)
            let answer: HyperliquidExchangeAnswer<HyperliquidCancelStatuses> = try await exchange(
                HyperliquidActions.cancel(asset: coin.index, oid: id.oid), vault: try await vault(for: account)
            )
            if let refusal = answer.response.data?.refusal {
                throw ExchangeClientError.refused(code: nil, text: refusal)
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // MARK: The account

    /// The value, the withdrawable amount and the open positions of `account`, in USDC and the coins' holdings
    ///
    /// `mode` is the account mode of the main wallet (`userAbstraction`), whichever account is read. A position the
    /// account holds in a coin whose holding is not declared refuses the whole read.
    public func accountState(account: String) async throws -> ExchangeClientAccountState<HyperliquidMarketName> {
        do {
            try declared.get()
            let address = try await self.address(of: account)
            let clearing: HyperliquidClearinghouseState = try await info(.map([("type", .string("clearinghouseState")), ("user", .string(address))]))
            let contexts: HyperliquidMetaAndContexts = try await info(.map([("type", .string("metaAndAssetCtxs"))]))
            let abstraction: HyperliquidJSONText = try await info(.map([("type", .string("userAbstraction")), ("user", .string(try await mainWallet()))]))

            var positions: [ExchangeClientPosition<HyperliquidMarketName>] = []
            for held in clearing.assetPositions.map(\.position) where held.szi.digits != 0 {
                let market = try HyperliquidMarketName(validating: held.coin)
                let base = try await self.coin(market).declared()
                guard let mark = contexts.context(of: held.coin)?.markPx, let entry = held.entryPx else {
                    throw ExchangeClientError.unknownMarket(market)
                }
                let units = try WireDecimal(digits: held.szi.digits < 0 ? -held.szi.digits : held.szi.digits, fractionDigits: held.szi.fractionDigits).amount(of: base, in: registry)
                positions.append(ExchangeClientPosition(
                    market: market, side: held.szi.digits > 0 ? .buy : .sell, units: units,
                    entryPrice: try entry.price(of: usdc, per: base, in: registry),
                    mark: try mark.price(of: usdc, per: base, in: registry),
                    liquidationPrice: try held.liquidationPx.map { try $0.price(of: usdc, per: base, in: registry) }
                ))
            }
            return ExchangeClientAccountState(
                balance: try clearing.marginSummary.accountValue.amount(of: usdc, in: registry),
                withdrawable: try clearing.withdrawable.amount(of: usdc, in: registry),
                positions: positions,
                mode: Self.mode(named: abstraction.text),
                readAt: Date(wireMilliseconds: clearing.time)
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // The leverage set on each coin the key's main wallet holds a position in, as its clearinghouse state states it;
    // none for a client without a credential, which has no account to read. C31's markets name no account, so the
    // main wallet's is the one read (a reading for the owner's pen); a coin with no position states none.
    private func leverageSet() async throws -> [String: Int] {
        guard credential != nil else {
            return [:]
        }
        let clearing: HyperliquidClearinghouseState = try await info(.map([("type", .string("clearinghouseState")), ("user", .string(try await mainWallet()))]))
        var set: [String: Int] = [:]
        for held in clearing.assetPositions.map(\.position) where held.szi.digits != 0 {
            set[held.coin] = held.leverage?.value
        }
        return set
    }

    // Hyperliquid's account modes ("abstractions"), as its info endpoint names them. Under the unified account and
    // under portfolio margin Hyperliquid refuses the perpetual class transfer between accounts (the POC's evidence,
    // 2026-09-17); under portfolio margin it trades cross margin only (a reading for the owner's pen).
    static func mode(named name: String) -> ExchangeClientAccountMode {
        let all = ["disabled", "unifiedAccount", "portfolioMargin"]
        return ExchangeClientAccountMode(
            name: name,
            allowsTransfer: name != "unifiedAccount" && name != "portfolioMargin",
            allowsIsolatedMargin: name != "portfolioMargin",
            alternatives: all.filter { $0 != name }
        )
    }

    /// What a fill did to the position, from Hyperliquid's `dir` word: "Open Long" and "Open Short" open, "Close Long"
    /// and "Close Short" close; any other word (a flip such as "Long > Short", a spot "Buy") states no effect, `nil`
    static func positionEffect(dir: String) -> ExchangeClientPositionEffect? {
        positionEffects[dir]
    }

    /// Hyperliquid's `dir` words that state a fill's position effect; a word not here states none
    static let positionEffects: [String: ExchangeClientPositionEffect] = [
        "Open Long": .open, "Open Short": .open,
        "Close Long": .close, "Close Short": .close
    ]

    /// The fills, the funding payments and the deposits, withdrawals and internal moves of `account` after `since`
    ///
    /// Reads from `since`'s millisecond (from time 0 when `nil`) and hands up, in order, only the items after the
    /// cursor `{milliseconds, place}`; each item carries its own cursor (``HyperliquidLedgerCursor``). A fill's time
    /// is Hyperliquid's, and its position effect is the one Hyperliquid states in the fill's `dir` ("Open Long" and
    /// "Open Short" open, "Close Long" and "Close Short" close; any other word, `nil`). Update kinds the shared ledger
    /// has no case for are not handed up.
    public func ledgerItems(account: String, since: HyperliquidLedgerCursor?) async throws -> [ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidLedgerCursor>] {
        do {
            try declared.get()
            let address = try await self.address(of: account)
            let start = HyperliquidWireValue.integer(since?.milliseconds ?? 0)
            let fills: [HyperliquidFill] = try await info(.map([("type", .string("userFillsByTime")), ("user", .string(address)), ("startTime", start)]))
            let funding: [HyperliquidFunding] = try await info(.map([("type", .string("userFunding")), ("user", .string(address)), ("startTime", start)]))
            let updates: [HyperliquidLedgerUpdate] = try await info(.map([("type", .string("userNonFundingLedgerUpdates")), ("user", .string(address)), ("startTime", start)]))

            // Each item with its millisecond and its order within the millisecond: the fills by trade id, then the
            // funding by coin, then the other updates by hash; its cursor is made once the order is known.
            typealias Made = (HyperliquidLedgerCursor) -> ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidLedgerCursor>
            var items: [(time: Int64, rank: Int, key: String, make: Made)] = []
            for fill in fills {
                let market = try HyperliquidMarketName(validating: fill.coin)
                let base = try await self.coin(market).declared()
                let closedBy: ExchangeClientCloseReason? = fill.liquidation ? .liquidation : fill.dir.contains("Auto-Deleveraging") ? .deleveraging : nil
                let units = try fill.sz.amount(of: base, in: registry)
                let price = try fill.px.price(of: usdc, per: base, in: registry)
                let fee = try fill.fee.amount(of: usdc, in: registry)
                // The trade id as 20 digits, so that text orders it as a number does.
                let tid = fill.tid.map(String.init) ?? ""
                let key = String(repeating: "0", count: max(0, 20 - tid.count)) + tid
                items.append((fill.time, 0, key, { cursor in
                    .fill(market: market, side: fill.side == "B" ? .buy : .sell, units: units, price: price, fee: fee,
                          order: HyperliquidOrderId(fill.oid), closedBy: closedBy, time: Date(wireMilliseconds: fill.time), cursor: cursor,
                          positionEffect: Self.positionEffect(dir: fill.dir))
                }))
            }
            for payment in funding {
                let market = try HyperliquidMarketName(validating: payment.delta.coin)
                let amount = try payment.delta.usdc.amount(of: usdc, in: registry)
                let rate = try Self.rate(payment.delta.fundingRate)
                items.append((payment.time, 1, payment.delta.coin, { cursor in
                    .funding(market: market, amount: amount, rate: rate, time: Date(wireMilliseconds: payment.time), cursor: cursor)
                }))
            }
            for update in updates {
                let time = Date(wireMilliseconds: update.time)
                let made: Made
                switch update.delta {
                case .deposit(let amount):
                    let amount = try amount.amount(of: usdc, in: registry)
                    made = { .deposit(amount, time: time, cursor: $0) }
                case .withdrawal(let amount):
                    let amount = try amount.amount(of: usdc, in: registry)
                    made = { .withdrawal(amount, time: time, cursor: $0) }
                case .move(let amount, let from, let to):
                    let amount = try amount.amount(of: usdc, in: registry)
                    made = { .internalMove(amount, from: from, to: to, time: time, cursor: $0) }
                case .other:
                    // A kind C30 has no case for (a vault's, a staking reward, a liquidation's own update, which the
                    // fills carry): not handed up (a reading for the owner's pen).
                    continue
                }
                items.append((update.time, 2, update.hash ?? "", made))
            }
            items.sort { ($0.time, $0.rank, $0.key) < ($1.time, $1.rank, $1.key) }

            // Each item's place among the items of its millisecond, 1 for the first; a read from a cursor hands up only
            // what lies after it.
            var handedUp: [ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidLedgerCursor>] = []
            var place = 0
            for (index, item) in items.enumerated() {
                place = index > 0 && items[index - 1].time == item.time ? place + 1 : 1
                let cursor = HyperliquidLedgerCursor(milliseconds: item.time, place: place)
                if let since, (cursor.milliseconds, cursor.place) <= (since.milliseconds, since.place) {
                    continue
                }
                handedUp.append(item.make(cursor))
            }
            return handedUp
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // A funding rate exactly, or cut toward zero at a Fraction's nine digits: Hyperliquid states rates to ten.
    static func rate(_ text: WireDecimal) throws -> Fraction {
        guard text.fractionDigits > 9 else {
            return try text.fraction()
        }
        let cut = text.digits / WireDecimal.powerOfTen(text.fractionDigits - 9)
        return try WireDecimal(digits: cut, fractionDigits: 9).fraction()
    }

    /// Sets the leverage of `market` for `account`, cross unless `isolated`
    public func setLeverage(_ leverage: Int, market: HyperliquidMarketName, isolated: Bool, account: String) async throws {
        do {
            let coin = try await self.coin(market)
            let answer: HyperliquidExchangeAnswer<HyperliquidNoData> = try await exchange(
                HyperliquidActions.updateLeverage(asset: coin.index, isCross: !isolated, leverage: leverage), vault: try await vault(for: account)
            )
            _ = answer
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// Moves USDC between the main account and one of its sub-accounts, signed by the agent key
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when `amount` is not USDC, or when neither `from` nor `to`
    ///   is the main account
    public func transfer(_ amount: Amount, from: String, to: String) async throws {
        do {
            try declared.get()
            guard amount.instance == usdc else {
                throw ExchangeClientError.wrongAsset
            }
            let main = try await mainWallet()
            let source = try await address(of: from)
            let destination = try await address(of: to)
            let action: HyperliquidWireValue
            switch (source == main, destination == main) {
            case (true, false):
                action = HyperliquidActions.subAccountTransfer(subAccount: destination, isDeposit: true, microUSD: Int64(amount.baseUnits))
            case (false, true):
                action = HyperliquidActions.subAccountTransfer(subAccount: source, isDeposit: false, microUSD: Int64(amount.baseUnits))
            default:
                throw ExchangeClientError.transferNeedsTheMainAccount
            }
            let answer: HyperliquidExchangeAnswer<HyperliquidNoData> = try await exchange(action, vault: nil)
            _ = answer
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // MARK: The key and the exchange's limits

    /// What the key may do: a main wallet's own key trades, moves and withdraws; an approved agent trades and moves
    /// while its approval lasts and never withdraws; a key no wallet approved does nothing
    public func keyFacts() async throws -> ExchangeClientKeyFacts {
        do {
            let key = try agentKey()
            // A key that is itself a main wallet is handed up as one: it trades, moves and withdraws, and nobody approved
            // it (T41, T53: the consumer refuses it; the client only says what it is).
            let role: HyperliquidUserRole = try await info(.map([("type", .string("userRole")), ("user", .string(key.address))]))
            if role.role == "user" {
                return ExchangeClientKeyFacts(canTrade: true, canTransfer: true, canWithdraw: true, approvedBy: nil, validUntil: nil)
            }
            let main = try await mainWallet()
            let agents: [HyperliquidAgent] = try await info(.map([("type", .string("extraAgents")), ("user", .string(main))]))
            guard let mine = agents.first(where: { $0.address.lowercased() == key.address }) else {
                return ExchangeClientKeyFacts(canTrade: false, canTransfer: false, canWithdraw: false, approvedBy: nil, validUntil: nil)
            }
            // An agent places and cancels orders and moves money between the main account's own sub-accounts; it never
            // withdraws (AR33). Hyperliquid states when the approval ends.
            let validUntil = mine.validUntil.map { Date(wireMilliseconds: $0) }
            let live = validUntil.map { $0 > now() } ?? true
            return ExchangeClientKeyFacts(canTrade: live, canTransfer: live, canWithdraw: false, approvedBy: main, validUntil: validUntil)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// Hyperliquid's address-based limit: the requests its main wallet has made against the cap its traded volume
    /// has earned; the cap grows with volume and resets at no time, so `resetsAt` is `Date.distantFuture`
    public func requestBudget() async throws -> ExchangeClientRequestBudget {
        do {
            let limit: HyperliquidRateLimit = try await info(.map([("type", .string("userRateLimit")), ("user", .string(try await mainWallet()))]))
            return ExchangeClientRequestBudget(limit: limit.nRequestsCap, remaining: max(0, limit.nRequestsCap - limit.nRequestsUsed), resetsAt: .distantFuture)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    /// Hyperliquid announces no maintenance window through its API: always empty
    public func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow] {
        []
    }

    /// A delisting for each perpetual Hyperliquid's `meta` marks delisted, effective when read: Hyperliquid states no date
    public func notices() async throws -> [ExchangeClientNotice<HyperliquidMarketName>] {
        do {
            let meta = try await perpMeta(refresh: true)
            let read = now()
            return try meta.universe.filter { $0.isDelisted == true }.map {
                ExchangeClientNotice(kind: .delisting, market: try HyperliquidMarketName(validating: $0.name), effectiveAt: read, text: "isDelisted")
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // MARK: The wire

    private func agentKey() throws -> HyperliquidAgentKey {
        guard case .agentKey(let key) = credential else {
            throw ExchangeClientError.noCredential
        }
        return key
    }

    // The main wallet whose agent the key is: asked of Hyperliquid once (`userRole`).
    private func mainWallet() async throws -> String {
        if let known = await state.mainWallet {
            return known
        }
        let key = try agentKey()
        let role: HyperliquidUserRole = try await info(.map([("type", .string("userRole")), ("user", .string(key.address))]))
        guard role.role == "agent", let main = role.data?.user.lowercased() else {
            throw ExchangeClientError.notAnAgent
        }
        await state.keep(mainWallet: main)
        return main
    }

    // An account's address: an address as given, lower-cased; a sub-account's name through the main wallet's list.
    private func address(of account: String) async throws -> String {
        if account.hasPrefix("0x"), (try? HyperliquidSigning.addressBytes(account)) != nil {
            return account.lowercased()
        }
        if let known = await state.subAccount(account) {
            return known
        }
        let subs: [HyperliquidSubAccount]? = try await info(.map([("type", .string("subAccounts")), ("user", .string(try await mainWallet()))]))
        for sub in subs ?? [] {
            await state.keep(subAccount: sub.name, address: sub.subAccountUser.lowercased())
        }
        guard let address = await state.subAccount(account) else {
            throw ExchangeClientError.unknownAccount(account)
        }
        return address
    }

    // The vault an action is signed for: none for the main wallet's own account, the sub-account's address otherwise.
    private func vault(for account: String) async throws -> String? {
        let address = try await self.address(of: account)
        return address == (try await mainWallet()) ? nil : address
    }

    private func coin(_ market: HyperliquidMarketName) async throws -> HyperliquidCoin {
        if let known = await state.coin(market.text) {
            return known
        }
        _ = try await perpMeta(refresh: false)
        guard let coin = await state.coin(market.text) else {
            throw ExchangeClientError.unknownMarket(market)
        }
        return coin
    }

    // Hyperliquid's perpetuals, each coin with its declared holding through the table, checked against the size
    // decimals Hyperliquid states (AR45); a coin the table lacks or the statement does not declare is kept with none.
    private func perpMeta(refresh: Bool) async throws -> HyperliquidMeta {
        try declared.get()
        let meta: HyperliquidMeta = try await info(.map([("type", .string("meta"))]))
        var coins: [String: HyperliquidCoin] = [:]
        for (index, listed) in meta.universe.enumerated() {
            let base = try HyperliquidExchangeChain.declaredInstance(wireName: listed.name, decimals: listed.szDecimals, in: registry)
            coins[listed.name] = HyperliquidCoin(index: index, name: listed.name, base: base)
        }
        await state.keep(coins)
        return meta
    }

    private func info<Value: Decodable & Sendable>(_ request: HyperliquidWireValue) async throws -> Value {
        try await ClientFetch.send(
            endpoint.baseURL.appendingPathComponent("info"), method: "POST", body: Data(request.json.utf8),
            session: session, errorForResponse: Self.refusal(for:body:)
        )
    }

    // One signed action to the exchange endpoint: the action, its nonce, its signature, and the sub-account it is for.
    private func exchange<Data_: Decodable & Sendable>(_ action: HyperliquidWireValue, vault: String?) async throws -> HyperliquidExchangeAnswer<Data_> {
        let key = try agentKey()
        let nonce = await state.nextNonce(at: now().wireMilliseconds)
        let hash = try HyperliquidSigning.actionHash(action, nonce: UInt64(nonce), vaultAddress: vault)
        let signature = key.sign(digest: HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: endpoint.isMainnet))
        var body: [(String, HyperliquidWireValue)] = [
            ("action", action),
            ("nonce", .integer(nonce)),
            ("signature", .map([
                ("r", .string("0x" + signature.r.toHexString())),
                ("s", .string("0x" + signature.s.toHexString())),
                ("v", .integer(Int64(signature.v)))
            ]))
        ]
        if let vault {
            body.append(("vaultAddress", .string(vault)))
        }
        return try await ClientFetch.send(
            endpoint.baseURL.appendingPathComponent("exchange"), method: "POST", body: Data(HyperliquidWireValue.map(body).json.utf8),
            session: session, errorType: HyperliquidAPIError.self, errorForResponse: Self.refusal(for:body:)
        )
    }

    // Hyperliquid's HTTP refusals as typed errors; nil for a 2xx, which the fetch reads (an "err" status in a 200
    // is the fetch's errorType, HyperliquidAPIError).
    static func refusal(for response: HTTPURLResponse, body: Data?) -> (any Error)? {
        switch response.statusCode {
        case 200..<300:
            nil
        case 429:
            ExchangeClientError.rateLimited(retryAfter: WireResponse.retryAfter(response))
        default:
            ExchangeClientError.rejected(status: response.statusCode, text: body.map { String(decoding: $0, as: UTF8.self) } ?? "")
        }
    }
}

/// The actions the agent signs, in the key order Hyperliquid hashes (the SDK's schemas' order)
package enum HyperliquidActions {
    // The order wire's keys in the SDK's order, a, b, p, s, r, t, and c, the cloid, last where there is one.
    package static func order(asset: Int, isBuy: Bool, limit: String, size: String, reduceOnly: Bool, timeInForce: String,
                              cloid: String? = nil) -> HyperliquidWireValue {
        var wire: [(String, HyperliquidWireValue)] = [
            ("a", .integer(Int64(asset))),
            ("b", .bool(isBuy)),
            ("p", .string(limit)),
            ("s", .string(size)),
            ("r", .bool(reduceOnly)),
            ("t", .map([("limit", .map([("tif", .string(timeInForce))]))]))
        ]
        if let cloid {
            wire.append(("c", .string(cloid)))
        }
        return .map([
            ("type", .string("order")),
            ("orders", .array([.map(wire)])),
            ("grouping", .string("na"))
        ])
    }

    package static func cancel(asset: Int, oid: Int64) -> HyperliquidWireValue {
        .map([("type", .string("cancel")), ("cancels", .array([.map([("a", .integer(Int64(asset))), ("o", .integer(oid))])]))])
    }

    package static func updateLeverage(asset: Int, isCross: Bool, leverage: Int) -> HyperliquidWireValue {
        .map([("type", .string("updateLeverage")), ("asset", .integer(Int64(asset))), ("isCross", .bool(isCross)), ("leverage", .integer(Int64(leverage)))])
    }

    package static func subAccountTransfer(subAccount: String, isDeposit: Bool, microUSD: Int64) -> HyperliquidWireValue {
        .map([("type", .string("subAccountTransfer")), ("subAccountUser", .string(subAccount.lowercased())), ("isDeposit", .bool(isDeposit)), ("usd", .integer(microUSD))])
    }
}

// What a client learns once and keeps: the main wallet, the sub-accounts, the coins, the last nonce.
private actor HyperliquidClientState {
    private(set) var mainWallet: String?
    private var subAccounts: [String: String] = [:]
    private var coins: [String: HyperliquidCoin] = [:]
    private var lastNonce: Int64 = 0

    func keep(mainWallet: String) { self.mainWallet = mainWallet }
    func subAccount(_ name: String) -> String? { subAccounts[name] }
    func keep(subAccount name: String, address: String) { subAccounts[name] = address }
    func coin(_ name: String) -> HyperliquidCoin? { coins[name] }

    func keep(_ coins: [String: HyperliquidCoin]) { self.coins = coins }

    // Hyperliquid wants each nonce larger than the last: the clock's milliseconds, or one past the last nonce.
    func nextNonce(at milliseconds: Int64) -> Int64 {
        lastNonce = Swift.max(milliseconds, lastNonce + 1)
        return lastNonce
    }
}

// A perpetual's index in `meta`, its name, and its declared holding, nil where undeclared.
struct HyperliquidCoin: Sendable {
    let index: Int
    let name: String
    let base: AssetInstance?

    // The coin's declared holding: the only kind a money value is made in.
    func declared() throws -> AssetInstance {
        guard let base else { throw ExchangeClientError.unknownAsset(name) }
        return base
    }
}
