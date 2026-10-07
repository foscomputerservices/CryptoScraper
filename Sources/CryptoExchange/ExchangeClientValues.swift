// ExchangeClientValues.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// C30: the exchange clients' values. Nothing here is a consumer's: the side is buy or sell, the ids and cursors are
// each client's own types, and the market name is the exchange's own, a type parameter, since an exchange's name for
// a market is the consumer's mapping to keep (R8). The declarations are C30's, with the market as the identity design
// amends it (§ 5.3: the symbols, decimals and optional holdings), its `alternateName`, and the open order's
// `clientOrderId`, none of which the protocols document's C30 yet carries; the memberwise initializers are added so
// each client, and a consumer's tests, can make the values (C30 shows none).

/// Buy or sell, the exchange's words for an order's direction
public enum ExchangeClientSide: Codable, Hashable, Sendable, Stubbable { case buy, sell }

/// A market as the exchange lists it: the declared holdings it trades, and the exchange's own names and decimals for
/// them as facts, every number parsed exactly from the exchange's text
///
/// The holdings are the exchange chain's declared constants, resolved through its table of wire names (design § 1.3,
/// § 5.3); a name the table lacks, or a holding the statement does not declare, leaves `base` or `quote` `nil` and
/// the amounts in it `nil`: no money value is made in an undeclared holding. The exchange's symbols and decimals are
/// handed up beside them, for the finding and the units check (AR45), never as an identity.
///
/// ```swift
/// let btc = try await client.markets().first { $0.name == name }
/// btc?.base                   // exchange:kraken:XBT, or nil where nothing is declared
/// btc?.baseDecimals           // 10, as Kraken states it
/// btc?.lotSize                // the smallest step of an order's size, in the base holding
/// btc?.minimumOrder           // the smallest order the exchange takes, in the instance the exchange states it in
/// ```
public struct ExchangeClientMarket<Name: Hashable & Sendable>: Hashable, Sendable {
    public let name: Name
    /// The second name the exchange accepts for the same market, Kraken's "XBTUSD" beside "XXBTZUSD"; `nil` where the
    /// exchange has one name for it
    public let alternateName: Name?
    /// What the exchange calls the base, and the decimals it states for it
    public let baseSymbol: AssetSymbol
    public let baseDecimals: Int
    /// What the exchange calls the quote, and the decimals it states for it
    public let quoteSymbol: AssetSymbol
    public let quoteDecimals: Int
    /// The declared holding on this exchange chain; `nil` where nothing is declared
    public let base: AssetInstance?
    /// The declared holding on this exchange chain; `nil` where nothing is declared
    public let quote: AssetInstance?
    /// The smallest step of an order's size, in the base holding; `nil` where the base is undeclared
    public let lotSize: Amount?
    /// The smallest order the exchange takes, in the instance the exchange states it in (the base on Kraken and
    /// Coinbase; on Hyperliquid its documented ten dollars, a constant of the client, in its USDC holding, so stated
    /// even where the base is undeclared); `nil` where that instance is undeclared
    public let minimumOrder: Amount?
    public let maxLeverage: Int?
    public let leverageSet: Int?
    public let isPerpetual: Bool

    public init(name: Name, alternateName: Name?, baseSymbol: AssetSymbol, baseDecimals: Int, quoteSymbol: AssetSymbol, quoteDecimals: Int,
                base: AssetInstance?, quote: AssetInstance?, lotSize: Amount?, minimumOrder: Amount?,
                maxLeverage: Int?, leverageSet: Int?, isPerpetual: Bool) {
        self.name = name
        self.alternateName = alternateName
        self.baseSymbol = baseSymbol
        self.baseDecimals = baseDecimals
        self.quoteSymbol = quoteSymbol
        self.quoteDecimals = quoteDecimals
        self.base = base
        self.quote = quote
        self.lotSize = lotSize
        self.minimumOrder = minimumOrder
        self.maxLeverage = maxLeverage
        self.leverageSet = leverageSet
        self.isPerpetual = isPerpetual
    }
}

/// A market's book as the exchange states it: its mid, its best bid and ask, its two volumes, and when it was read
///
/// ```swift
/// let book = try await client.orderBook(market: name)
/// let gap = book.bestBid.spread(to: book.bestAsk)       // the spread, a Fraction
/// ```
public struct ExchangeClientBook<Name: Hashable & Sendable>: Hashable, Sendable {
    public let market: Name
    public let mid: Price
    public let bestBid: Price
    public let bestAsk: Price
    /// The last day's trading: the base asset traded, as the exchange publishes it, and the turnover in the quote
    /// asset, as the exchange publishes it where it does (Hyperliquid's, Coinbase's where it states one) and otherwise
    /// the base volume priced at the mid (Kraken's, Coinbase's where it writes none); the turnover is cut toward zero
    /// at the quote holding's base unit
    public let baseVolume: Amount
    public let quoteVolume: Amount
    /// The exchange's own time for the book where it states one (Hyperliquid's, Coinbase's); otherwise the client's
    /// clock when the answer arrived (Kraken's, or Coinbase's where it states none)
    public let readAt: Date

    public init(market: Name, mid: Price, bestBid: Price, bestAsk: Price, baseVolume: Amount, quoteVolume: Amount, readAt: Date) {
        self.market = market
        self.mid = mid
        self.bestBid = bestBid
        self.bestAsk = bestAsk
        self.baseVolume = baseVolume
        self.quoteVolume = quoteVolume
        self.readAt = readAt
    }
}

/// What came of an order, as the exchange said
///
/// ```swift
/// switch try await client.placeOrder(market: name, side: .buy, size: size, limit: limit,
///                                    immediateOrCancel: true, reduceOnly: false, clientOrderId: token, account: account) {
/// case .filled(let units, let price, let id, _): …
/// case .refused(let code, let text): …          // the exchange's own words
/// default: …
/// }
/// ```
///
/// Each `time` is the exchange's own where its answer states one (Kraken's close or open time, Coinbase's last fill
/// time); where the exchange's answer states none (Hyperliquid's order answer, a Coinbase order with no fill yet),
/// it is the client's clock when the answer arrived.
public enum ExchangeClientOrderResult<OrderId: Hashable & Sendable>: Hashable, Sendable {
    case filled(units: Amount, at: Price, id: OrderId, time: Date)
    case partlyFilled(units: Amount, at: Price, id: OrderId, time: Date)
    /// Accepted and resting on the book, nothing filled yet; the fills arrive as ledger items (AR40's sweep reads it)
    case resting(id: OrderId, time: Date)
    case cancelledBeforeAccepted
    case cancelled(id: OrderId)
    case refused(code: String, text: String)
}

/// An order resting on the exchange's book
public struct ExchangeClientOpenOrder<Name: Hashable & Sendable, OrderId: Hashable & Sendable>: Hashable, Sendable {
    public let id: OrderId
    public let market: Name
    public let side: ExchangeClientSide
    /// The units still waiting to fill
    public let units: Amount
    /// The consumer's own id the order was placed with (``ExchangeClient/placeOrder(market:side:size:limit:immediateOrCancel:reduceOnly:clientOrderId:account:)``),
    /// as the exchange hands it back; `nil` where the exchange states none, or one that is not 128 bits in a form the
    /// client writes
    public let clientOrderId: UInt128?

    public init(id: OrderId, market: Name, side: ExchangeClientSide, units: Amount, clientOrderId: UInt128?) {
        self.id = id
        self.market = market
        self.side = side
        self.units = units
        self.clientOrderId = clientOrderId
    }
}

/// An account's money, its positions and its mode, as the exchange states them
public struct ExchangeClientAccountState<Name: Hashable & Sendable>: Hashable, Sendable {
    public let balance: Amount
    public let withdrawable: Amount
    public let positions: [ExchangeClientPosition<Name>]
    public let mode: ExchangeClientAccountMode
    /// The exchange's own time for the state where it states one (Hyperliquid's); otherwise the client's clock when
    /// the answer arrived (Kraken's, Coinbase's)
    public let readAt: Date

    public init(balance: Amount, withdrawable: Amount, positions: [ExchangeClientPosition<Name>],
                mode: ExchangeClientAccountMode, readAt: Date) {
        self.balance = balance
        self.withdrawable = withdrawable
        self.positions = positions
        self.mode = mode
        self.readAt = readAt
    }
}

/// A position the exchange holds for an account
public struct ExchangeClientPosition<Name: Hashable & Sendable>: Hashable, Sendable {
    public let market: Name
    public let side: ExchangeClientSide
    public let units: Amount
    public let entryPrice: Price
    public let mark: Price
    public let liquidationPrice: Price?

    public init(market: Name, side: ExchangeClientSide, units: Amount, entryPrice: Price, mark: Price,
                liquidationPrice: Price?) {
        self.market = market
        self.side = side
        self.units = units
        self.entryPrice = entryPrice
        self.mark = mark
        self.liquidationPrice = liquidationPrice
    }
}

/// An account's mode as the exchange names it, and what the mode allows
public struct ExchangeClientAccountMode: Hashable, Sendable {
    public let name: String
    public let allowsTransfer: Bool
    public let allowsIsolatedMargin: Bool
    public let alternatives: [String]

    public init(name: String, allowsTransfer: Bool, allowsIsolatedMargin: Bool, alternatives: [String]) {
        self.name = name
        self.allowsTransfer = allowsTransfer
        self.allowsIsolatedMargin = allowsIsolatedMargin
        self.alternatives = alternatives
    }
}

/// Why the exchange closed a position itself
public enum ExchangeClientCloseReason: Codable, Hashable, Sendable { case liquidation, deleveraging, settlement, halt }

/// What a fill did to the position, as the exchange states it: the FIX protocol's position effect
///
/// `open` adds to a position or starts one; `close` reduces a position or ends one. A fill carries `nil` where the
/// exchange states none (a spot fill). The exchange's own words ("Open Long", "Close Short") live only in its
/// plug-in's table, which maps them to this value; they are never handed up as text.
public enum ExchangeClientPositionEffect: String, Codable, Hashable, Sendable, CaseIterable, Stubbable {
    /// The fill added to a position or started one
    case open
    /// The fill reduced a position or ended one
    case close
}

/// An item of the exchange's own ledger, each kind with its values, every one carrying the cursor after it
///
/// ```swift
/// for item in try await client.ledgerItems(account: account, since: cursor) {
///     if case .fill(_, _, _, _, let fee, let order, _, _, _, _) = item { … }   // the fee read, never estimated
/// }
/// ```
///
/// A fill's `positionEffect` is what the fill did to the position, as the exchange states it, `nil` where the
/// exchange states none; it is last and defaults to `nil`, so a fill made without it states no effect.
public enum ExchangeClientLedgerItem<Name: Hashable & Sendable, OrderId: Hashable & Sendable, Cursor: Hashable & Sendable>: Hashable, Sendable {
    case fill(market: Name, side: ExchangeClientSide, units: Amount, price: Price, fee: Amount, order: OrderId, closedBy: ExchangeClientCloseReason?, time: Date, cursor: Cursor, positionEffect: ExchangeClientPositionEffect? = nil)
    case funding(market: Name, amount: Amount, rate: Fraction, time: Date, cursor: Cursor)
    case deposit(Amount, time: Date, cursor: Cursor)
    case withdrawal(Amount, time: Date, cursor: Cursor)
    case internalMove(Amount, from: String, to: String, time: Date, cursor: Cursor)
}

/// What the client's key may do, as the exchange states it
public struct ExchangeClientKeyFacts: Hashable, Sendable {
    public let canTrade: Bool
    public let canTransfer: Bool
    public let canWithdraw: Bool
    public let approvedBy: String?
    public let validUntil: Date?

    public init(canTrade: Bool, canTransfer: Bool, canWithdraw: Bool, approvedBy: String?, validUntil: Date?) {
        self.canTrade = canTrade
        self.canTransfer = canTransfer
        self.canWithdraw = canWithdraw
        self.approvedBy = approvedBy
        self.validUntil = validUntil
    }
}

/// The exchange's published request limit and how much of it is left
///
/// Where the exchange states its count (Hyperliquid), `remaining` is its own; where it publishes only the limit
/// (Kraken, Coinbase), `remaining` is the limit less the client's own count of its requests in the current window,
/// and `resetsAt` is that window's end.
public struct ExchangeClientRequestBudget: Hashable, Sendable {
    public let limit: Int
    public let remaining: Int
    /// When the window ends; `Date.distantFuture` where the exchange's limit resets on no clock (Hyperliquid's)
    public let resetsAt: Date

    public init(limit: Int, remaining: Int, resetsAt: Date) {
        self.limit = limit
        self.remaining = remaining
        self.resetsAt = resetsAt
    }
}

/// What an exchange client throws: one set of meanings over every exchange, the exchange's own code and text carried inside
///
/// A plug-in maps its wire errors into these once; the drivers above read one type (C24, C16).
public enum ExchangeClientError: Error, Hashable, Sendable {
    /// The exchange refused the request and said why; `code` is the exchange's own
    case refused(code: String?, text: String)
    /// A rate limit, with the time the exchange says to wait when it says one
    case rateLimited(retryAfter: Duration?)
    /// The credential was not accepted
    case unauthorized(text: String)
    /// No answer, or a transport failure; the text is the transport's
    case unreachable(text: String)
    /// An answer that did not decode as the exchange documents it
    case malformedResponse(text: String)
    /// A member this exchange does not offer (a spot market has no leverage)
    case notOffered(member: String)
}

/// A maintenance window the exchange announced, with what it affects: trading, transfers (deposits and withdrawals), or something else
///
/// The client classifies the exchange's announcement into the subject; the engine holds a stream on a trading window only (C16).
public struct ExchangeClientMaintenanceWindow: Hashable, Sendable {
    public enum Subject: Codable, Hashable, Sendable { case trading, transfers, other }
    public let subject: Subject
    public let interval: DateInterval
    public let text: String

    public init(subject: Subject, interval: DateInterval, text: String) {
        self.subject = subject
        self.interval = interval
        self.text = text
    }
}

/// The exchange's notice that a market will be delisted, renamed or halted
public struct ExchangeClientNotice<Name: Hashable & Sendable>: Hashable, Sendable {
    public enum Kind: Codable, Hashable, Sendable { case delisting, rename, halt }
    public let kind: Kind
    public let market: Name
    public let effectiveAt: Date
    public let text: String

    public init(kind: Kind, market: Name, effectiveAt: Date, text: String) {
        self.kind = kind
        self.market = market
        self.effectiveAt = effectiveAt
        self.text = text
    }
}

extension ExchangeClientSide {
    public static func stub() -> Self { .buy }
}

extension ExchangeClientPositionEffect {
    public static func stub() -> Self { .open }
}

// The forms the exchanges take a 128-bit client order id in, written and read back by the plug-ins.
extension UInt128 {
    /// The 32 lower-case hex digits of the value, zero-padded: Kraken's short UUID form, and Hyperliquid's after "0x"
    package var clientOrderIdHex: String {
        let digits = String(self, radix: 16)
        return String(repeating: "0", count: 32 - digits.count) + digits
    }

    /// The value as a UUID's text, 8-4-4-4-12 lower-case hex digits: Kraken's long form and Coinbase's
    package var clientOrderIdUUIDText: String {
        let hex = Array(clientOrderIdHex)
        return [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(hex[$0]) }.joined(separator: "-")
    }

    /// The value an exchange handed back in one of those forms ("0x" and 32 hex digits, 32 hex digits, or a UUID's
    /// text, in either case); `nil` for any other text, which is not an id written in a form the clients write
    package init?(clientOrderIdText text: String) {
        var hex = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        if hex.count == 36, [8, 13, 18, 23].allSatisfy({ hex[hex.index(hex.startIndex, offsetBy: $0)] == "-" }) {
            hex.removeAll { $0 == "-" }
        }
        guard hex.count == 32, hex.allSatisfy(\.isHexDigit), let value = UInt128(hex, radix: 16) else {
            return nil
        }
        self = value
    }
}
