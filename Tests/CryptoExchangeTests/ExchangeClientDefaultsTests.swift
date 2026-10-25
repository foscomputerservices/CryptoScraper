// ExchangeClientDefaultsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import Foundation
import Testing

// C31's members with a default: a conformer that declares only the members it had before still conforms.

/// A conformer that reads no wallet: every member it declares throws, and `holdings` is the protocol's default
private struct WalletlessClient: ExchangeClient {
    typealias Credential = String
    typealias MarketName = String
    typealias OrderId = Int
    typealias TransferId = String
    typealias Cursor = Int

    func markets() async throws -> [ExchangeClientMarket<String>] { [] }
    func orderBook(market: String) async throws -> ExchangeClientBook<String> { throw ExchangeClientError.notOffered(member: "orderBook") }
    func placeOrder(market: String, side: ExchangeClientSide, size: Amount, limit: Price, immediateOrCancel: Bool, reduceOnly: Bool,
                    clientOrderId: UInt128?, account: String) async throws -> ExchangeClientOrderResult<Int> {
        throw ExchangeClientError.notOffered(member: "placeOrder")
    }
    func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<String, Int>] { [] }
    func cancelOrder(_ id: Int, market: String, account: String) async throws {}
    func accountState(account: String) async throws -> ExchangeClientAccountState<String> { throw ExchangeClientError.notOffered(member: "accountState") }
    func ledgerItems(account: String, since: Int?) async throws -> [ExchangeClientLedgerItem<String, Int, Int, String, Int>] { [] }
    func setLeverage(_ leverage: Int, market: String, isolated: Bool, account: String) async throws {}
    func transfer(_ amount: Amount, from: String, to: String) async throws {}
    func keyFacts() async throws -> ExchangeClientKeyFacts { throw ExchangeClientError.notOffered(member: "keyFacts") }
    func requestBudget() async throws -> ExchangeClientRequestBudget { throw ExchangeClientError.notOffered(member: "requestBudget") }
    func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow] { [] }
    func notices() async throws -> [ExchangeClientNotice<String>] { [] }
    var hasTestMarket: Bool { false }
}

@Suite("C31: the members with a default")
struct ExchangeClientDefaultsTests {
    @Test func aConformerThatReadsNoWalletIsNotOfferedHoldings() async {
        await #expect(throws: ExchangeClientError.notOffered(member: "holdings")) { try await WalletlessClient().holdings(account: "") }
        await #expect(throws: ExchangeClientError.notOffered(member: "feeRates")) { try await WalletlessClient().feeRates(account: "") }
    }
}
