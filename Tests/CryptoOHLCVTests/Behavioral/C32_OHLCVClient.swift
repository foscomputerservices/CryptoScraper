// C32_OHLCVClient.swift — C32: the OHLCV client's protocol, its two members and their types

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("C32: the OHLCV client's protocol")
struct C32_OHLCVClientTests {
    /// A conformer written from C32's declaration alone: it compiles only if the protocol has exactly these members' shapes
    struct ScriptedClient: OHLCVClient {
        typealias MarketName = String
        let closed: [OHLCVClientBar]
        let open: OHLCVClientBar?

        func ohlcv(market: String, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar] { closed }
        func openOHLCV(market: String, interval: BarInterval) async throws -> OHLCVClientBar? { open }
    }

    /// A consumer generic over the protocol, calling both members as C32's DocC example does
    func consume<C: OHLCVClient>(_ client: C, market: C.MarketName) async throws -> ([OHLCVClientBar], OHLCVClientBar?) {
        let bars = try await client.ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute),
                                          from: date(ms: Fx.jan1Ms), through: date(ms: Fx.jan1Ms + Fx.dayMs))
        let open = try await client.openOHLCV(market: market, interval: BarInterval(count: 1, unit: .day))
        return (bars, open)
    }

    @Test("C32: a conformer of the two declared members, ohlcv and openOHLCV, satisfies the protocol")
    func twoMembers() async throws {
        let closed = OHLCVClientBar.stub(isClosed: true)
        let open = OHLCVClientBar.stub(isClosed: false)
        let (bars, live) = try await consume(ScriptedClient(closed: [closed], open: open), market: "BTCUSDT")
        #expect(bars == [closed])
        #expect(live == open)
    }

    @Test("C32: the Binance conformer is an OHLCVClient, reachable through a generic consumer")
    func binanceConforms() async throws {
        let session = RecordedSession(BinanceFixtures.dailyClosed)
        let (bars, _) = try await consume(Fx.binance(session), market: Fx.btcusdt)
        #expect(bars.count == 2)
    }

    @Test("C32: the protocol and its conformer are Sendable")
    func sendable() {
        let client = Fx.binance(RecordedSession(BinanceFixtures.empty))
        let sendable: any Sendable = client
        #expect(sendable is BinanceOHLCVClient)
    }

    @Test("C32: the market name is the conformer's own type, Hashable and Sendable")
    func marketNameHashableSendable() {
        func requireHashableSendable<M: Hashable & Sendable>(_ market: M) -> M { market }
        let a = requireHashableSendable(Fx.btcusdt)
        let b = requireHashableSendable(Fx.btcusdt)
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }
}
