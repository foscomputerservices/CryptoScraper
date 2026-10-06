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
///                                          immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x")
/// ```
///
/// **Accounts.** An account is Hyperliquid's own name for it: a sub-account's name as the main wallet lists it
/// ("four-hour-2x"), or an address ("0x…"), the main wallet's own included.
///
/// **Numbers.** A market's base asset is its coin at the coin's size decimals, so one lot is one base unit; its
/// quote is USDC at six decimals (``Asset/usdc``), Hyperliquid's unit of account. Every number Hyperliquid sends as
/// text is decoded exactly but two, each cut toward zero: a funding rate finer than nine digits at a ``Fraction``'s
/// nine, and a book's day notional finer than USDC's six at six. A book's volume is the day's notional in USDC
/// (`dayNtlVlm`), the quote, never base units: C35 divides it by a stake in the stream's unit of account.
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

    /// - Parameters:
    ///   - credential: The agent key that signs; `nil` for a client that only reads the markets and the books
    ///   - endpoint: The test market or production
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock: each signed action's nonce is its milliseconds, kept increasing
    public init(
        credential: HyperliquidCredential?,
        endpoint: HyperliquidEndpoint,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credential = credential
        self.endpoint = endpoint
        self.session = session
        self.now = now
        self.state = HyperliquidClientState()
    }

    public var hasTestMarket: Bool { true }

    // MARK: Markets and books

    public func markets() async throws -> [ExchangeClientMarket<HyperliquidMarketName>] {
        do {
            let meta = try await perpMeta(refresh: true)
            return try meta.universe.filter { $0.isDelisted != true }.map { coin in
                let name = try HyperliquidMarketName(validating: coin.name)
                let base = try Asset(symbol: coin.name, unitExponent: coin.szDecimals)
                return ExchangeClientMarket(
                    name: name, base: base, quote: .usdc,
                    lotSize: Amount(baseUnits: 1, asset: base),
                    minimumOrder: Amount(whole: 10, of: .usdc),
                    maxLeverage: coin.maxLeverage, leverageSet: nil, isPerpetual: true
                )
            }
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    public func orderBook(market: HyperliquidMarketName) async throws -> ExchangeClientBook<HyperliquidMarketName> {
        do {
            let coin = try await self.coin(market)
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
                mid: try mid.price(of: .usdc, per: coin.asset),
                bestBid: try bid.price(of: .usdc, per: coin.asset),
                bestAsk: try ask.price(of: .usdc, per: coin.asset),
                volume: try Self.notional(context.dayNtlVlm),
                readAt: Date(wireMilliseconds: book.time)
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // MARK: Orders

    public func placeOrder(market: HyperliquidMarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                           immediateOrCancel: Bool, reduceOnly: Bool, account: String) async throws -> ExchangeClientOrderResult<HyperliquidOrderId> {
        do {
            let coin = try await self.coin(market)
            guard size.asset == coin.asset, limit.base == coin.asset, limit.quote == .usdc else {
                throw ExchangeClientError.wrongAsset
            }
            let action = HyperliquidActions.order(asset: coin.index, isBuy: side == .buy, limit: WireDecimal(limit).text,
                                                  size: WireDecimal(size).text, reduceOnly: reduceOnly,
                                                  timeInForce: immediateOrCancel ? "Ioc" : "Gtc")
            let answer: HyperliquidExchangeAnswer<HyperliquidOrderStatuses> = try await exchange(action, vault: try await vault(for: account))
            guard let status = answer.response.data?.statuses.first else {
                throw ExchangeClientError.refused(code: nil, text: "Hyperliquid answered the order with no status")
            }
            let time = now()
            switch status {
            case .filled(let totalSize, let averagePrice, let oid):
                let units = try totalSize.amount(of: coin.asset)
                let price = try averagePrice.price(of: .usdc, per: coin.asset)
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

    public func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<HyperliquidMarketName, HyperliquidOrderId>] {
        do {
            let address = try await self.address(of: account)
            let orders: [HyperliquidOpenOrder] = try await info(.map([("type", .string("openOrders")), ("user", .string(address))]))
            var open: [ExchangeClientOpenOrder<HyperliquidMarketName, HyperliquidOrderId>] = []
            for order in orders {
                let market = try HyperliquidMarketName(validating: order.coin)
                let coin = try await self.coin(market)
                open.append(ExchangeClientOpenOrder(id: HyperliquidOrderId(order.oid), market: market,
                                                    side: order.side == "B" ? .buy : .sell, units: try order.sz.amount(of: coin.asset)))
            }
            return open
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

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

    public func accountState(account: String) async throws -> ExchangeClientAccountState<HyperliquidMarketName> {
        do {
            let address = try await self.address(of: account)
            let clearing: HyperliquidClearinghouseState = try await info(.map([("type", .string("clearinghouseState")), ("user", .string(address))]))
            let contexts: HyperliquidMetaAndContexts = try await info(.map([("type", .string("metaAndAssetCtxs"))]))
            let abstraction: HyperliquidJSONText = try await info(.map([("type", .string("userAbstraction")), ("user", .string(try await mainWallet()))]))

            var positions: [ExchangeClientPosition<HyperliquidMarketName>] = []
            for held in clearing.assetPositions.map(\.position) where held.szi.digits != 0 {
                let market = try HyperliquidMarketName(validating: held.coin)
                let coin = try await self.coin(market)
                guard let mark = contexts.context(of: held.coin)?.markPx, let entry = held.entryPx else {
                    throw ExchangeClientError.unknownMarket(market)
                }
                let units = try WireDecimal(digits: held.szi.digits < 0 ? -held.szi.digits : held.szi.digits, fractionDigits: held.szi.fractionDigits).amount(of: coin.asset)
                positions.append(ExchangeClientPosition(
                    market: market, side: held.szi.digits > 0 ? .buy : .sell, units: units,
                    entryPrice: try entry.price(of: .usdc, per: coin.asset),
                    mark: try mark.price(of: .usdc, per: coin.asset),
                    liquidationPrice: try held.liquidationPx.map { try $0.price(of: .usdc, per: coin.asset) }
                ))
            }
            return ExchangeClientAccountState(
                balance: try clearing.marginSummary.accountValue.amount(of: .usdc),
                withdrawable: try clearing.withdrawable.amount(of: .usdc),
                positions: positions,
                mode: Self.mode(named: abstraction.text),
                readAt: Date(wireMilliseconds: clearing.time)
            )
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
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

    public func ledgerItems(account: String, since: HyperliquidLedgerCursor?) async throws -> [ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidLedgerCursor>] {
        do {
            let address = try await self.address(of: account)
            let start = HyperliquidWireValue.integer(since?.milliseconds ?? 0)
            let fills: [HyperliquidFill] = try await info(.map([("type", .string("userFillsByTime")), ("user", .string(address)), ("startTime", start)]))
            let funding: [HyperliquidFunding] = try await info(.map([("type", .string("userFunding")), ("user", .string(address)), ("startTime", start)]))
            let updates: [HyperliquidLedgerUpdate] = try await info(.map([("type", .string("userNonFundingLedgerUpdates")), ("user", .string(address)), ("startTime", start)]))

            var items: [(Int64, ExchangeClientLedgerItem<HyperliquidMarketName, HyperliquidOrderId, HyperliquidLedgerCursor>)] = []
            for fill in fills {
                let market = try HyperliquidMarketName(validating: fill.coin)
                let coin = try await self.coin(market)
                let closedBy: ExchangeClientCloseReason? = fill.liquidation ? .liquidation : fill.dir.contains("Auto-Deleveraging") ? .deleveraging : nil
                items.append((fill.time, .fill(
                    market: market, side: fill.side == "B" ? .buy : .sell,
                    units: try fill.sz.amount(of: coin.asset), price: try fill.px.price(of: .usdc, per: coin.asset),
                    fee: try fill.fee.amount(of: .usdc), order: HyperliquidOrderId(fill.oid), closedBy: closedBy,
                    time: Date(wireMilliseconds: fill.time), cursor: HyperliquidLedgerCursor(milliseconds: fill.time)
                )))
            }
            for payment in funding {
                items.append((payment.time, .funding(
                    market: try HyperliquidMarketName(validating: payment.delta.coin),
                    amount: try payment.delta.usdc.amount(of: .usdc),
                    rate: try Self.rate(payment.delta.fundingRate),
                    time: Date(wireMilliseconds: payment.time), cursor: HyperliquidLedgerCursor(milliseconds: payment.time)
                )))
            }
            for update in updates {
                let time = Date(wireMilliseconds: update.time)
                let cursor = HyperliquidLedgerCursor(milliseconds: update.time)
                switch update.delta {
                case .deposit(let amount):
                    items.append((update.time, .deposit(try amount.amount(of: .usdc), time: time, cursor: cursor)))
                case .withdrawal(let amount):
                    items.append((update.time, .withdrawal(try amount.amount(of: .usdc), time: time, cursor: cursor)))
                case .move(let amount, let from, let to):
                    items.append((update.time, .internalMove(try amount.amount(of: .usdc), from: from, to: to, time: time, cursor: cursor)))
                case .other:
                    // A kind C30 has no case for (a vault's, a staking reward, a liquidation's own update, which the
                    // fills carry): not handed up (a reading for the owner's pen).
                    continue
                }
            }
            return items.sorted { $0.0 < $1.0 }.map(\.1)
        } catch {
            throw ExchangeClientError.mapping(error, translating: ExchangeClientError.hyperliquid)
        }
    }

    // The day's notional as an amount of USDC, exactly, or cut toward zero at USDC's six digits: Hyperliquid states it
    // as the sum of its fills' notionals, which carries up to ten digits (BTC's "1994433.2905599999" on the test market).
    static func notional(_ text: WireDecimal) throws -> Amount {
        let exponent = Asset.usdc.unitExponent
        guard text.fractionDigits > exponent else {
            return try text.amount(of: .usdc)
        }
        let cut = text.digits / WireDecimal.powerOfTen(text.fractionDigits - exponent)
        return try WireDecimal(digits: cut, fractionDigits: exponent).amount(of: .usdc)
    }

    // A funding rate exactly, or cut toward zero at a Fraction's nine digits: Hyperliquid states rates to ten.
    static func rate(_ text: WireDecimal) throws -> Fraction {
        guard text.fractionDigits > 9 else {
            return try text.fraction()
        }
        let cut = text.digits / WireDecimal.powerOfTen(text.fractionDigits - 9)
        return try WireDecimal(digits: cut, fractionDigits: 9).fraction()
    }

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

    public func transfer(_ amount: Amount, from: String, to: String) async throws {
        do {
            guard amount.asset == .usdc else {
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

    private func perpMeta(refresh: Bool) async throws -> HyperliquidMeta {
        let meta: HyperliquidMeta = try await info(.map([("type", .string("meta"))]))
        await state.keep(meta)
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
    package static func order(asset: Int, isBuy: Bool, limit: String, size: String, reduceOnly: Bool, timeInForce: String) -> HyperliquidWireValue {
        .map([
            ("type", .string("order")),
            ("orders", .array([.map([
                ("a", .integer(Int64(asset))),
                ("b", .bool(isBuy)),
                ("p", .string(limit)),
                ("s", .string(size)),
                ("r", .bool(reduceOnly)),
                ("t", .map([("limit", .map([("tif", .string(timeInForce))]))]))
            ])])),
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

    func keep(_ meta: HyperliquidMeta) {
        for (index, coin) in meta.universe.enumerated() {
            if let asset = try? Asset(symbol: coin.name, unitExponent: coin.szDecimals) { // a coin whose name is no asset symbol is not tradable here
                coins[coin.name] = HyperliquidCoin(index: index, asset: asset)
            }
        }
    }

    // Hyperliquid wants each nonce larger than the last: the clock's milliseconds, or one past the last nonce.
    func nextNonce(at milliseconds: Int64) -> Int64 {
        lastNonce = Swift.max(milliseconds, lastNonce + 1)
        return lastNonce
    }
}

struct HyperliquidCoin: Sendable {
    let index: Int
    let asset: Asset
}
