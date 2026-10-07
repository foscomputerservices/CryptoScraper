// ExchangeClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// C31. The declaration and its DocC are the protocols document's, with `clientOrderId` on `placeOrder` added on
// 2026-10-07, which that document's C31 does not yet carry. Three conformers, one per plug-in library:
// HyperliquidClient (CryptoHyperliquid), KrakenClient (CryptoKraken), CoinbaseClient (CryptoCoinbase), each on
// FOSFoundation's fetch with the exchange's error decoded by `errorType` and mapped into C30's ExchangeClientError (AR31), holding no file.

/// The public contract of one exchange's client: its REST, its signing, its errors as ``ExchangeClientError``, its facts as values
///
/// A client decides nothing: it hands up what the exchange says, typed. A consumer's own layer decides.
///
/// Every member throws ``ExchangeClientError``, except that a cancellation of the calling task is thrown as it is, a
/// `CancellationError`.
///
/// ```swift
/// let client = try HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket, session: session)
/// let book = try await client.orderBook(market: "BTC")
/// let placed = try await client.placeOrder(market: "BTC", side: .buy, size: size, limit: limit,
///                                          immediateOrCancel: true, reduceOnly: false, clientOrderId: id.token, account: account)
/// ```
///
/// Every text an exchange sends for a number is decoded into § 1's types inside the client's response models, exactly; nothing typed as a string leaves a client.
public protocol ExchangeClient: Sendable {
    associatedtype Credential: Sendable
    associatedtype MarketName: Hashable & Sendable
    /// The exchange's own id for an order, as its API has it
    associatedtype OrderId: Codable & Hashable & Sendable
    /// Where this exchange resumes a read of its ledger, as its API has it
    associatedtype Cursor: Codable & Hashable & Sendable

    func markets() async throws -> [ExchangeClientMarket<MarketName>]
    func orderBook(market: MarketName) async throws -> ExchangeClientBook<MarketName>
    /// Places an order; `clientOrderId` is the consumer's own id for it, made before the send (T56, C22's 128-bit token),
    /// written in the form the exchange takes (Hyperliquid's `cloid`, Kraken's `cl_ord_id`, Coinbase's
    /// `client_order_id`), so an order that went unanswered can be found by it among the open orders; `nil` sends none,
    /// except to Coinbase, which requires one: its client then sends a fresh random UUID
    func placeOrder(market: MarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, clientOrderId: UInt128?, account: String) async throws -> ExchangeClientOrderResult<OrderId>
    func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<MarketName, OrderId>]
    func cancelOrder(_ id: OrderId, market: MarketName, account: String) async throws
    func accountState(account: String) async throws -> ExchangeClientAccountState<MarketName>
    func ledgerItems(account: String, since: Cursor?) async throws -> [ExchangeClientLedgerItem<MarketName, OrderId, Cursor>]
    func setLeverage(_ leverage: Int, market: MarketName, isolated: Bool, account: String) async throws
    func transfer(_ amount: Amount, from: String, to: String) async throws
    func keyFacts() async throws -> ExchangeClientKeyFacts
    func requestBudget() async throws -> ExchangeClientRequestBudget
    func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow]
    func notices() async throws -> [ExchangeClientNotice<MarketName>]
    var hasTestMarket: Bool { get }
}
