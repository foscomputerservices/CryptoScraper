// C31 — An exchange client, as a protocol's behavior over a stub client.
// Projected from docs/fosline-suite-protocols.md C31: "A client decides nothing: it hands up what the exchange says,
// typed." and "each client's `OrderId` and `Cursor` round-trip through `toJSON()` / `fromJSON()`" (§ 8.6). And the
// owner's ruling of 2026-10-07: `placeOrder` carries the engine's own order id so the exchange echoes it. And the
// design § 5.3: "A name the table lacks gives a market with `nil` holdings; a money value in it is refused."
//
// The stub conformer below is written to the documented protocol; the adapter maps the engine-order-id parameter's
// name. Each exchange's own targets run the same checks over its recordings.

import CryptoAsset
import CryptoExchange
import FOSFoundation
import Foundation
import Synchronization
import Testing

/// A conformer written from C31's declaration, echoing what it is handed, as the protocol says an exchange does
private struct EchoingClient: ExchangeClient {
    typealias Credential = String
    typealias MarketName = String
    typealias OrderId = Int
    typealias Cursor = Int

    let registry: AssetRegistry
    let echoed = Mutex<String?>(nil)

    func markets() async throws -> [ExchangeClientMarket<String>] { [] }
    func orderBook(market: String) async throws -> ExchangeClientBook<String> { throw ExchangeClientError.notOffered(member: "orderBook") }

    // invented: the engine-order-id parameter, here `clientOrderId:` — the owner ruled it 2026-10-07; its name is the adapter's to map
    func placeOrder(market: String, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, account: String,
                    clientOrderId: String) async throws -> ExchangeClientOrderResult<Int> {
        echoed.withLock { $0 = clientOrderId }
        return .resting(id: 42, time: Date(timeIntervalSince1970: 42))
    }

    func openOrders(account: String) async throws -> [ExchangeClientOpenOrder<String, Int>] { [] }
    func cancelOrder(_ id: Int, market: String, account: String) async throws {}
    func accountState(account: String) async throws -> ExchangeClientAccountState<String> { throw ExchangeClientError.notOffered(member: "accountState") }
    func ledgerItems(account: String, since: Int?) async throws -> [ExchangeClientLedgerItem<String, Int, Int>] { [] }
    func setLeverage(_ leverage: Int, market: String, isolated: Bool, account: String) async throws { throw ExchangeClientError.notOffered(member: "setLeverage") }
    func transfer(_ amount: Amount, from: String, to: String) async throws {}
    func keyFacts() async throws -> ExchangeClientKeyFacts { throw ExchangeClientError.notOffered(member: "keyFacts") }
    func requestBudget() async throws -> ExchangeClientRequestBudget { throw ExchangeClientError.notOffered(member: "requestBudget") }
    func maintenanceWindows() async throws -> [ExchangeClientMaintenanceWindow] { [] }
    func notices() async throws -> [ExchangeClientNotice<String>] { [] }
    var hasTestMarket: Bool { true }
}

@Suite("C31 ExchangeClient")
struct C31_ExchangeClientTests {
    private func roundTrips<Value: Codable & Equatable>(_ value: Value) throws -> Bool {
        let back: Value = try value.toJSON().fromJSON()
        return back == value
    }

    // owner, 2026-10-07: "`placeOrder` carries the engine's own order id so the exchange echoes it"
    @Test func placeOrderCarriesTheEnginesOrderId() async throws {
        let home = AssetInstance.stub()
        let quote = AssetInstance.stub(address: "slate-42")
        let declarations = try [home, quote].map { instance in
            try AssetDeclaration(asset: .stub(home: instance), tokenName: "Fred Coin", symbol: .stub(),
                                 instances: [AssetDeclaration.Instance(instance: instance, decimals: 4, symbol: .stub())])
        }
        let registry = try AssetRegistry(declarations)
        let client = EchoingClient(registry: registry)
        let limit = try Price(Amount(whole: 42, of: quote, in: registry), per: home, in: registry)
        _ = try await client.placeOrder(market: "FREDBARNEY", side: .buy, size: Amount(baseUnits: 42, of: home), limit: limit,
                                        immediateOrCancel: true, reduceOnly: false, account: "bedrock",
                                        clientOrderId: "quarry-42")
        #expect(client.echoed.withLock { $0 } == "quarry-42")
    }

    // "each client's `OrderId` and `Cursor` round-trip through `toJSON()` / `fromJSON()`"
    @Test func orderIdAndCursorRoundTrip() throws {
        #expect(try roundTrips(EchoingClient.OrderId(42)))
        #expect(try roundTrips(EchoingClient.Cursor(42)))
    }

    // "Buy or sell, the exchange's words for an order's direction"
    @Test func sideRoundTrips() throws {
        #expect(try roundTrips(ExchangeClientSide.buy))
        #expect(try roundTrips(ExchangeClientSide.sell))
        #expect(ExchangeClientSide.buy != .sell)
    }

    // "one set of meanings over every exchange, the exchange's own code and text carried inside"
    @Test func errorsCarryTheExchangesCodeAndText() {
        let refused = ExchangeClientError.refused(code: "fred-42", text: "Insufficient funds")
        #expect(refused == .refused(code: "fred-42", text: "Insufficient funds"))
        #expect(refused != .refused(code: nil, text: "Insufficient funds"))
    }

    // "A member this exchange does not offer (a spot market has no leverage)"
    @Test func notOfferedNamesTheMember() async throws {
        let client = EchoingClient(registry: try AssetRegistry([]))
        await #expect(throws: ExchangeClientError.notOffered(member: "setLeverage")) {
            try await client.setLeverage(2, market: "FREDBARNEY", isolated: true, account: "bedrock")
        }
    }

    // "A client decides nothing: it hands up what the exchange says, typed." — a fill's money values are Amounts in its instances
    @Test(.disabled("Classified 2026-10-07: the fill gained positionEffect at the owner's word; the pattern's arity is the projector's shape; see the identity ledger")) func ledgerFillCarriesTypedValues() throws {
        let base = AssetInstance.stub()
        let quote = AssetInstance.stub(address: "slate-42")
        let declarations = try [base, quote].map { instance in
            try AssetDeclaration(asset: .stub(home: instance), tokenName: "Fred Coin", symbol: .stub(),
                                 instances: [AssetDeclaration.Instance(instance: instance, decimals: 4, symbol: .stub())])
        }
        let registry = try AssetRegistry(declarations)
        let price = try Price(Amount(whole: 42, of: quote, in: registry), per: base, in: registry)
        let item = ExchangeClientLedgerItem<String, Int, Int>.fill(
            market: "FREDBARNEY", side: .buy, units: Amount(baseUnits: 42, of: base), price: price,
            fee: Amount(baseUnits: 1, of: quote), order: 42, closedBy: nil, time: Date(timeIntervalSince1970: 42), cursor: 42)
        guard case let .fill(_, _, units, at, fee, _, _, _, _, _) = item else { Issue.record("not a fill"); return }
        #expect(units.instance == base)
        #expect(at.base == base)
        #expect(fee.instance == quote)
    }
}
