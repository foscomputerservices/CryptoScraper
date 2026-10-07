// C31 — The client-order-id echo, on Coinbase.
// Projected from the owner's ruling of 2026-10-07: `placeOrder` carries the engine's own order id so the exchange
// echoes it. And docs/fosline-suite-protocols.md C31: "A client decides nothing: it hands up what the exchange says,
// typed." Recorded answers only; never a live call.

import CryptoAsset
import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("C31 Coinbase order id echo")
struct C31_CoinbaseOrderIdEchoTests {
    // invented: as in D53 — CoinbaseClient(credential:session:registry:), CoinbaseCredential.stub(), RecordedCoinbase.session(answering:)
    private func client(_ recording: String) throws -> (CoinbaseClient, AssetRegistry) {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        return (try CoinbaseClient(credential: .stub(), session: RecordedCoinbase.session(answering: recording), registry: registry),
                registry)
    }

    // owner, 2026-10-07: "`placeOrder` carries the engine's own order id" — the request sent carries it
    @Test(.disabled("Classified 2026-10-07: needs placeOrder(…, account:, clientOrderId: String), not declared: the code's id is clientOrderId: UInt128? before account: (C22's 128-bit token), and a text has no 128-bit reading; see the identity ledger")) func requestCarriesTheEnginesOrderId() async throws {
        let (client, registry) = try client("orders-create")
        // invented: CoinbaseHolding.btc / .usd — Coinbase's constants are not written out
        let btc = AssetInstance(CoinbaseHolding.btc)
        let usd = AssetInstance(CoinbaseHolding.usd)
        let markets = try await client.markets()
        let btcusd = try #require(markets.first { $0.base == btc && $0.quote == usd })
        let limit = try Price(Amount(whole: 65_000, of: usd, in: registry), per: btc, in: registry)
        // invented: the engine-order-id parameter, here `clientOrderId:` — the adapter maps its name
        _ = try await client.placeOrder(market: btcusd.name, side: .buy, size: try #require(btcusd.lotSize), limit: limit,
                                        immediateOrCancel: true, reduceOnly: false, account: "quarry-42",
                                        clientOrderId: "quarry-42-order")
        // invented: RecordedCoinbase.lastRequestBody — the recorded session's view of what was sent
        #expect(RecordedCoinbase.lastRequestBody.contains("quarry-42-order"))
    }

    // owner, 2026-10-07: "so the exchange echoes it"
    @Test(.disabled("Classified 2026-10-07: no recording orders-historical-echo (an open order carrying an engine id), and it needs a String clientOrderId on the open order, not declared (C30's is UInt128?); see the identity ledger")) func openOrdersEchoTheEnginesOrderId() async throws {
        let (client, _) = try client("orders-historical-echo")
        // invented: ExchangeClientOpenOrder.clientOrderId — the echoed id's place is not declared
        #expect(try await client.openOrders(account: "quarry-42").contains { $0.clientOrderId == "quarry-42-order" })
    }
}
