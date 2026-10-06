// ExchangeClientValues.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// C30: the exchange clients' values. Nothing here is a consumer's: the side is buy or sell, the ids and cursors are
// each client's own types, and the market name is the exchange's own, a type parameter, since an exchange's name for
// a market is the consumer's mapping to keep (R8). The declarations are C30's; the memberwise initializers are added
// so each client, and a consumer's tests, can make the values (C30 shows none).

/// Buy or sell, the exchange's words for an order's direction
public enum ExchangeClientSide: Codable, Hashable, Sendable, Stubbable { case buy, sell }

/// A market as the exchange lists it, every number parsed exactly from the exchange's text
///
/// ```swift
/// let btc = try await client.markets().first { $0.name == name }
/// btc?.lotSize                // the smallest step of an order's size, in the base asset
/// btc?.minimumOrder           // the smallest order the exchange takes, in the base asset
/// ```
public struct ExchangeClientMarket<Name: Hashable & Sendable>: Hashable, Sendable {
    public let name: Name
    public let base: Asset
    public let quote: Asset
    public let lotSize: Amount
    public let minimumOrder: Amount
    public let maxLeverage: Int?
    public let leverageSet: Int?
    public let isPerpetual: Bool

    public init(name: Name, base: Asset, quote: Asset, lotSize: Amount, minimumOrder: Amount,
                maxLeverage: Int?, leverageSet: Int?, isPerpetual: Bool) {
        self.name = name
        self.base = base
        self.quote = quote
        self.lotSize = lotSize
        self.minimumOrder = minimumOrder
        self.maxLeverage = maxLeverage
        self.leverageSet = leverageSet
        self.isPerpetual = isPerpetual
    }
}

/// A market's book as the exchange states it: its mid, its best bid and ask, its volume, and when it was read
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
    /// The base asset traded over the exchange's last day, as the exchange states it
    public let volume: Amount
    public let readAt: Date

    public init(market: Name, mid: Price, bestBid: Price, bestAsk: Price, volume: Amount, readAt: Date) {
        self.market = market
        self.mid = mid
        self.bestBid = bestBid
        self.bestAsk = bestAsk
        self.volume = volume
        self.readAt = readAt
    }
}

/// What came of an order, as the exchange said
///
/// ```swift
/// switch try await client.placeOrder(market: name, side: .buy, size: size, limit: limit,
///                                    immediateOrCancel: true, reduceOnly: false, account: account) {
/// case .filled(let units, let price, let id, _): …
/// case .refused(let code, let text): …          // the exchange's own words
/// default: …
/// }
/// ```
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

    public init(id: OrderId, market: Name, side: ExchangeClientSide, units: Amount) {
        self.id = id
        self.market = market
        self.side = side
        self.units = units
    }
}

/// An account's money, its positions and its mode, as the exchange states them
public struct ExchangeClientAccountState<Name: Hashable & Sendable>: Hashable, Sendable {
    public let balance: Amount
    public let withdrawable: Amount
    public let positions: [ExchangeClientPosition<Name>]
    public let mode: ExchangeClientAccountMode
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

/// An item of the exchange's own ledger, each kind with its values, every one carrying the cursor after it
///
/// ```swift
/// for item in try await client.ledgerItems(account: account, since: cursor) {
///     if case .fill(_, _, _, _, let fee, let order, _, _, _) = item { … }   // the fee read, never estimated
/// }
/// ```
public enum ExchangeClientLedgerItem<Name: Hashable & Sendable, OrderId: Hashable & Sendable, Cursor: Hashable & Sendable>: Hashable, Sendable {
    case fill(market: Name, side: ExchangeClientSide, units: Amount, price: Price, fee: Amount, order: OrderId, closedBy: ExchangeClientCloseReason?, time: Date, cursor: Cursor)
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
public struct ExchangeClientRequestBudget: Hashable, Sendable {
    public let limit: Int
    public let remaining: Int
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
