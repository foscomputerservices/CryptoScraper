// ExchangeClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// C31. The declaration and its DocC are the protocols document's. Three conformers, one per plug-in library:
// HyperliquidClient (CryptoHyperliquid), KrakenClient (CryptoKraken), CoinbaseClient (CryptoCoinbase), each on
// FOSFoundation's fetch with the exchange's error decoded by `errorType` into a Swift Error (AR31), holding no file.

/// The public contract of one exchange's client: its REST, its signing, its typed errors, its facts as values
///
/// A client decides nothing: it hands up what the exchange says, typed. A consumer's own layer decides.
///
/// ```swift
/// let client = try HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket, session: session)
/// let book = try await client.orderBook(market: "BTC")
/// let placed = try await client.placeOrder(market: "BTC", side: .buy, size: size, limit: limit,
///                                          immediateOrCancel: true, reduceOnly: false, account: account)
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
    func placeOrder(market: MarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, account: String) async throws -> ExchangeClientOrderResult<OrderId>
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
