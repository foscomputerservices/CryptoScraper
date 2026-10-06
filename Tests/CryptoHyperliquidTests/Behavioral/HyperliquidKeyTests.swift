// HyperliquidKeyTests.swift — what only Hyperliquid's client hands up: the agent and its approval (T41, T53, T103, AR33),
// the test market, the request budget. The client decides nothing: a key that should stop the exchange leg is
// handed up as the fact it is, and the driver stops (C31: "A client decides nothing").
//
// ASSUMED SHAPE, every body: as HyperliquidScript.swift.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import Foundation
import Testing

@Suite("Hyperliquid: the agent, its approval, the test market, the budget")
struct HyperliquidKeyTests {
    let script = HyperliquidScript()

    private func client(_ routes: [ScriptedRoute]) throws -> (HyperliquidClient, ScriptedSession) {
        let session = ScriptedSession(routes)
        return (try script.makeClient(session: session, log: LogCapture()), session)
    }

    @Test("C31 hasTestMarket: Hyperliquid has one")
    func hasTestMarket() throws {
        let (client, _) = try client([])
        #expect(client.hasTestMarket)
    }

    @Test("T53, T41: the approver the exchange names is the main wallet, never the agent itself")
    func approverIsNotTheAgent() async throws {
        let (client, _) = try client(try script.keyFactsCase().routes)
        let facts = try await client.keyFacts()
        #expect(facts.approvedBy == HyperliquidScript.mainWallet)
        #expect(facts.approvedBy?.lowercased() != HyperliquidScript.agentAddress)
    }

    @Test("T41, T53: a key that is itself a main wallet is handed up as one: no approver, able to withdraw")
    func mainWalletKeyIsHandedUpAsTheFactItIs() async throws {
        // READING: a key whose role is "user" holds every permission and has no approver; the driver stops on it (T53)
        let (client, _) = try client([
            .json("userRole", #"{"role":"user"}"#),
            .json("extraAgents", "[]"),
        ])
        let facts = try await client.keyFacts()
        #expect(facts.approvedBy == nil)
        #expect(facts.canWithdraw)
        #expect(facts.validUntil == nil)
    }

    @Test("T103: an approval's expiry is the exchange's instant to the millisecond")
    func approvalExpiryIsExact() async throws {
        let (client, _) = try client([
            .json("userRole", #"{"role":"agent","data":{"user":"\#(HyperliquidScript.mainWallet)"}}"#),
            .json("extraAgents", #"[{"address":"0x3333333333333333333333333333333333333333","name":"other","validUntil":1700000000000},{"address":"\#(HyperliquidScript.agentAddress)","name":"fosline","validUntil":1769904000123}]"#),
        ])
        let facts = try await client.keyFacts()
        // the agent's own entry, not another agent's
        #expect(facts.validUntil == ms(1_769_904_000_123))
    }

    @Test("T103: an agent the main wallet no longer lists has no expiry handed up")
    func unlistedAgentHasNoExpiry() async throws {
        // READING: the role still names the main wallet, but the approval list has no entry for this agent
        let (client, _) = try client([
            .json("userRole", #"{"role":"agent","data":{"user":"\#(HyperliquidScript.mainWallet)"}}"#),
            .json("extraAgents", "[]"),
        ])
        let facts = try await client.keyFacts()
        #expect(facts.validUntil == nil)
    }

    @Test("C31 requestBudget, T52: the cap and what remains of it", .disabled("Classified 2026-10-06: the projector's script does not answer the setup requests the client makes first (userRole, meta), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md"))
    func requestBudget() async throws {
        let (client, _) = try client([
            .json("userRateLimit", #"{"cumVlm":"2854574.593578","nRequestsUsed":2890,"nRequestsCap":2864574}"#),
        ])
        let budget = try await client.requestBudget()
        #expect(budget.limit == 2_864_574)
        #expect(budget.remaining == 2_864_574 - 2890)
    }

    @Test("AR33: a sub-account's order is sent with the sub-account as its vault, signed by the agent", .disabled("Classified 2026-10-06: the projector's script does not answer the setup requests the client makes first (userRole, meta), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md"))
    func subAccountOrderNamesItsVault() async throws {
        let order = try script.filledOrder()
        let (client, session) = try client(order.routes)
        _ = try await client.placeOrder(market: "BTC", side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: HyperliquidScript.subAccount)
        let sent = session.everythingSent
        #expect(sent.contains("vaultAddress"))
        #expect(sent.contains(HyperliquidScript.subAccount))
        #expect(sent.contains("signature"))
    }

    @Test("C31: a reduce-only order says so on the wire", .disabled("Classified 2026-10-06: the projector's script does not answer the setup requests the client makes first (userRole, meta), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md"))
    func reduceOnlyIsSent() async throws {
        let order = try script.filledOrder()
        let (client, session) = try client(order.routes)
        _ = try await client.placeOrder(market: "BTC", side: .sell, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: true, account: HyperliquidScript.subAccount)
        #expect(session.everythingSent.contains("\"r\":true"))
        #expect(session.everythingSent.contains("\"b\":false"))
    }

    @Test("C31: a resting order is sent good-till-cancelled when immediateOrCancel is false", .disabled("Classified 2026-10-06: the projector's script does not answer the setup requests the client makes first (userRole, meta), so the session throws before the behavior is reached; see validation/step3-ledgers/layer-a-builder.md"))
    func restingOrderIsGoodTillCancelled() async throws {
        // the scripted answer is a fill; what a resting answer becomes is not asserted:
        // C30's result has no case for an order left resting
        let order = try script.filledOrder()
        let (client, session) = try client(order.routes)
        _ = try await client.placeOrder(market: "BTC", side: .buy, size: order.size, limit: order.limit, immediateOrCancel: false, reduceOnly: false, account: HyperliquidScript.subAccount)
        #expect(session.everythingSent.contains("Gtc"))
        #expect(!session.everythingSent.contains("Ioc"))
    }
}
