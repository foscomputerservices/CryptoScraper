// KrakenSigningTests.swift — AR32: an API key and an HMAC computed from the secret on each request; T40: the secret never leaves.
//
// ASSUMED SCHEME (from Kraken's derivatives documentation as known without a recording): headers APIKey, Nonce, Authent;
// Authent = base64( HMAC-SHA512( key: base64-decoded secret, message: SHA256( postData + nonce + endpointPath ) ) ),
// where postData is the form body (or the query for a GET) and endpointPath is the URL's path with "/derivatives" removed.
// The test recomputes it from what the request itself carries, so it needs no clock seam. If Kraken's scheme differs,
// the builder corrects the recomputation below to the documented one; the assertion (header == recomputation) stays.

import CryptoExchange
import CryptoKit
import CryptoKraken
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

@Suite("AR32: Kraken's HMAC")
struct KrakenSigningTests {
    let script = KrakenScript()

    private func placedOrder() async throws -> ScriptedSession {
        let order = try script.filledOrder()
        let session = ScriptedSession(order.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.placeOrder(market: script.market, side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: script.account)
        return session
    }

    private func orderRequest(_ session: ScriptedSession) throws -> URLRequest {
        try #require(session.requests.first { ScriptedSession.urlAndBody(of: $0).contains("sendorder") })
    }

    static func expectedAuthent(for request: URLRequest, secretBase64: String) throws -> String {
        let nonce = try #require(request.value(forHTTPHeaderField: "Nonce"))
        let url = try #require(request.url)
        let postData = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? (URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery ?? "")
        var path = url.path
        if path.hasPrefix("/derivatives") { path.removeFirst("/derivatives".count) }
        let digest = SHA256.hash(data: Data((postData + nonce + path).utf8))
        let key = SymmetricKey(data: try #require(Data(base64Encoded: secretBase64)))
        let mac = HMAC<SHA512>.authenticationCode(for: Data(digest), using: key)
        return Data(mac).base64EncodedString()
    }

    @Test("AR32: a private request carries the API key, a nonce and the HMAC")
    func privateRequestCarriesTheHeaders() async throws {
        let request = try orderRequest(try await placedOrder())
        #expect(request.value(forHTTPHeaderField: "APIKey") == KrakenScript.apiKey)
        #expect(request.value(forHTTPHeaderField: "Nonce") != nil)
        #expect(request.value(forHTTPHeaderField: "Authent") != nil)
    }

    @Test("AR32: the HMAC is the one computed from the secret over this request")
    func authentIsTheRecomputedHMAC() async throws {
        let request = try orderRequest(try await placedOrder())
        let expected = try Self.expectedAuthent(for: request, secretBase64: KrakenScript.secretBase64)
        #expect(request.value(forHTTPHeaderField: "Authent") == expected)
    }

    @Test("AR32: each request's nonce is larger than the last")
    func noncesIncrease() async throws {
        let transfer = try script.transferCase()
        let order = try script.filledOrder()
        let session = ScriptedSession(order.routes + transfer.scripted.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.placeOrder(market: script.market, side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: script.account)
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        let nonces = session.requests.compactMap { $0.value(forHTTPHeaderField: "Nonce") }.compactMap { UInt64($0) }
        #expect(nonces.count >= 2)
        #expect(zip(nonces, nonces.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("AR32: two different requests carry two different HMACs")
    func hmacDependsOnTheRequest() async throws {
        let transfer = try script.transferCase()
        let order = try script.filledOrder()
        let session = ScriptedSession(order.routes + transfer.scripted.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.placeOrder(market: script.market, side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: script.account)
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        let signatures = session.requests.compactMap { $0.value(forHTTPHeaderField: "Authent") }
        #expect(signatures.count >= 2)
        #expect(Set(signatures).count == signatures.count)
    }

    @Test("T40: a public request carries no key at all")
    func publicRequestCarriesNoKey() async throws {
        // READING: the instruments, the tickers and the book are public; the key rides only where the exchange needs it
        let session = ScriptedSession(KrakenScript.info)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.orderBook(market: script.market)
        expectNoSecret([KrakenScript.apiKey] + script.secretTexts, in: session.everythingSent, "a public request")
    }
}

@Suite("Kraken: the maintenance windows")
struct KrakenMaintenanceTests {
    @Test("C31 maintenanceWindows: the exchange's scheduled maintenance as an interval")
    func maintenanceWindows() async throws {
        // ASSUMED SHAPE and a READING: Kraken's notifications carry a maintenance's start and its expected minutes down
        let session = ScriptedSession([.json("notifications", """
        {"result":"success","notifications":[{"type":"maintenance","priority":"high","note":"Scheduled maintenance",\
        "effectiveTime":"2024-09-25T08:00:00.000Z","expectedDowntimeMinutes":60},\
        {"type":"new_feature","priority":"low","note":"A new feature","effectiveTime":"2024-09-26T08:00:00.000Z"}],\
        "serverTime":"2024-09-22T10:13:20.000Z"}
        """)])
        let client = try KrakenScript().makeClient(session: session, log: LogCapture())
        let windows = try await client.maintenanceWindows()
        #expect(windows == [DateInterval(start: try iso("2024-09-25T08:00:00.000Z"), duration: 3600)])
    }

    @Test("C31 hasTestMarket: Kraken's derivatives have a demo market")
    func hasTestMarket() throws {
        // READING: the client built on .testMarket says it has one
        let client = try KrakenScript().makeClient(session: ScriptedSession([]), log: LogCapture())
        #expect(client.hasTestMarket)
    }
}
