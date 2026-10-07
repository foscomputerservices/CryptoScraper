// C31 — The client-order-id echo, on Kraken.
// Projected from the owner's ruling of 2026-10-07: `placeOrder` carries the engine's own order id so the exchange
// echoes it. And docs/fosline-suite-protocols.md C31: "A client decides nothing: it hands up what the exchange says,
// typed." Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoKraken
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("C31 Kraken order id echo")
struct C31_KrakenOrderIdEchoTests {
    // invented: as in D53 — KrakenClient(credential:session:registry:), KrakenCredential.stub(), RecordedKraken.session(answering:)
    private func client(_ recording: String) throws -> (KrakenClient, AssetRegistry) {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        return (try KrakenClient(credential: .stub(), session: RecordedKraken.session(answering: recording), registry: registry),
                registry)
    }

    private func order(_ client: KrakenClient, _ registry: AssetRegistry, id: String) async throws -> ExchangeClientOrderResult<KrakenClient.OrderId> {
        let markets = try await client.markets()
        let xbtusd = try #require(markets.first { $0.base == AssetInstance(KrakenHolding.xbt) })
        let limit = try Price(Amount(whole: 65_000, of: AssetInstance(KrakenHolding.usd), in: registry),
                              per: AssetInstance(KrakenHolding.xbt), in: registry)
        // invented: the engine-order-id parameter, here `clientOrderId:` — the owner ruled it 2026-10-07; the adapter maps its name
        return try await client.placeOrder(market: xbtusd.name, side: .buy,
                                           size: Amount(baseUnits: 1_500_000_000, of: AssetInstance(KrakenHolding.xbt)),
                                           limit: limit, immediateOrCancel: true, reduceOnly: false,
                                           account: "bedrock", clientOrderId: id)
    }

    // owner, 2026-10-07: "`placeOrder` carries the engine's own order id" — the request sent to Kraken carries it
    @Test(.disabled("Classified 2026-10-07: needs placeOrder(…, account:, clientOrderId: String), not declared: the code's id is clientOrderId: UInt128? before account: (C22's 128-bit token), and a text has no 128-bit reading; see the identity ledger")) func requestCarriesTheEnginesOrderId() async throws {
        let (client, registry) = try client("AddOrder")
        _ = try await order(client, registry, id: "quarry-42")
        // invented: RecordedKraken.lastRequestBody — the recorded session's view of what was sent
        #expect(RecordedKraken.lastRequestBody.contains("quarry-42"))
    }

    // owner, 2026-10-07: "so the exchange echoes it" — the open order Kraken hands back carries the engine's id
    @Test(.disabled("Classified 2026-10-07: no recording OpenOrders-echo (an open order carrying an engine id), and it needs a String clientOrderId on the open order, not declared (C30's is UInt128?); see the identity ledger")) func openOrdersEchoTheEnginesOrderId() async throws {
        let (client, _) = try client("OpenOrders-echo")
        let open = try await client.openOrders(account: "bedrock")
        // invented: ExchangeClientOpenOrder.clientOrderId — the echoed id's place on C30's values is not declared
        #expect(open.contains { $0.clientOrderId == "quarry-42" })
    }

    // "A client decides nothing" — the exchange's own id is kept beside the echo, never replaced by it
    @Test(.disabled("Classified 2026-10-07: needs placeOrder(…, account:, clientOrderId: String), not declared: the code's id is clientOrderId: UInt128? before account: (C22's 128-bit token), and a text has no 128-bit reading; see the identity ledger")) func exchangesOwnIdStays() async throws {
        let (client, registry) = try client("AddOrder")
        let result = try await order(client, registry, id: "quarry-42")
        switch result {
        case let .filled(_, _, id, _), let .partlyFilled(_, _, id, _), let .resting(id, _):
            #expect("\(id)" != "quarry-42")
        default:
            Issue.record("the recorded AddOrder answer is an accepted order")
        }
    }
}
