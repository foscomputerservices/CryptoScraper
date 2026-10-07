// C31 — The client-order-id echo, on Hyperliquid.
// Projected from the owner's ruling of 2026-10-07: `placeOrder` carries the engine's own order id so the exchange
// echoes it. And docs/fosline-suite-protocols.md C31's example: "let placed = try await client.placeOrder(market:
// \"BTC\", side: .buy, size: size, limit: limit, immediateOrCancel: true, reduceOnly: false, account: account)".
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("C31 Hyperliquid order id echo")
struct C31_HyperliquidOrderIdEchoTests {
    // invented: as in D53 — the `registry:` label, RecordedHyperliquid.session(answering:), HyperliquidAgentKey.stub()
    private func client(_ recording: String) throws -> (HyperliquidClient, AssetRegistry) {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        return (try HyperliquidClient(credential: .agentKey(.stub()), endpoint: .testMarket,
                                      session: RecordedHyperliquid.session(answering: recording), registry: registry),
                registry)
    }

    // owner, 2026-10-07: "`placeOrder` carries the engine's own order id" — the signed action sent carries it
    @Test(.disabled("Classified 2026-10-07: needs placeOrder(…, account:, clientOrderId: String), not declared: the code's id is clientOrderId: UInt128? before account: (C22's 128-bit token), and a text has no 128-bit reading; see the identity ledger")) func requestCarriesTheEnginesOrderId() async throws {
        let (client, registry) = try client("exchange-order")
        let markets = try await client.markets()
        // invented: HyperliquidHolding.btc — the constant's Swift name is not declared
        let btc = AssetInstance(HyperliquidHolding.btc)
        let perp = try #require(markets.first { $0.base == btc })
        let limit = try Price(Amount(whole: 65_000, of: AssetInstance(HyperliquidHolding.usdc), in: registry), per: btc, in: registry)
        // invented: the engine-order-id parameter, here `clientOrderId:` — the adapter maps its name
        _ = try await client.placeOrder(market: perp.name, side: .buy, size: Amount(baseUnits: 15_000, of: btc), limit: limit,
                                        immediateOrCancel: true, reduceOnly: false, account: "four-hour-2x",
                                        clientOrderId: "quarry-42")
        // invented: RecordedHyperliquid.lastRequestBody — the recorded session's view of what was sent
        #expect(RecordedHyperliquid.lastRequestBody.contains("quarry-42"))
    }

    // owner, 2026-10-07: "so the exchange echoes it" — an open order handed back carries the engine's id
    @Test(.disabled("Classified 2026-10-07: no recording openOrders-echo (an open order carrying an engine id), and it needs a String clientOrderId on the open order, not declared (C30's is UInt128?); see the identity ledger")) func openOrdersEchoTheEnginesOrderId() async throws {
        let (client, _) = try client("openOrders-echo")
        // invented: ExchangeClientOpenOrder.clientOrderId — the echoed id's place is not declared
        #expect(try await client.openOrders(account: "four-hour-2x").contains { $0.clientOrderId == "quarry-42" })
    }
}
