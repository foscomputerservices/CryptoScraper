// CoinbaseSigningTests.swift — AR32: an API key and an HMAC computed from the secret on each request; T40: the secret never leaves.
//
// ASSUMED SCHEME (Coinbase's key-and-HMAC signing as known without a recording): headers CB-ACCESS-KEY, CB-ACCESS-SIGN,
// CB-ACCESS-TIMESTAMP; CB-ACCESS-SIGN = hex( HMAC-SHA256( key: the secret, message: timestamp + method + path + body ) ),
// the path without its query. The test recomputes it from what the request itself carries, so it needs no clock seam.
// If Coinbase's scheme differs, the builder corrects the recomputation to the documented one; the assertion stays.

import CryptoCoinbase
import CryptoExchange
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto  // Linux: swift-crypto's module, the same API
#endif
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

@Suite("AR32: Coinbase's HMAC")
struct CoinbaseSigningTests {
    let script = CoinbaseScript()

    private func placedOrder() async throws -> ScriptedSession {
        let order = try script.filledOrder()
        let session = ScriptedSession(order.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.placeOrder(market: script.market, side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: script.account)
        return session
    }

    private func orderRequest(_ session: ScriptedSession) throws -> URLRequest {
        try #require(session.requests.first { ScriptedSession.urlAndBody(of: $0).contains("order_configuration") })
    }

    static func expectedSign(for request: URLRequest, secret: String) throws -> String {
        let timestamp = try #require(request.value(forHTTPHeaderField: "CB-ACCESS-TIMESTAMP"))
        let method = request.httpMethod ?? "GET"
        let path = try #require(request.url).path
        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        let mac = HMAC<SHA256>.authenticationCode(for: Data((timestamp + method + path + body).utf8), using: SymmetricKey(data: Data(secret.utf8)))
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    @Test("AR32: a private request carries the API key, a timestamp and the HMAC")
    func privateRequestCarriesTheHeaders() async throws {
        let request = try orderRequest(try await placedOrder())
        #expect(request.value(forHTTPHeaderField: "CB-ACCESS-KEY") == CoinbaseScript.apiKey)
        #expect(request.value(forHTTPHeaderField: "CB-ACCESS-TIMESTAMP") != nil)
        #expect(request.value(forHTTPHeaderField: "CB-ACCESS-SIGN") != nil)
    }

    @Test("AR32: the HMAC is the one computed from the secret over this request")
    func signIsTheRecomputedHMAC() async throws {
        let request = try orderRequest(try await placedOrder())
        let expected = try Self.expectedSign(for: request, secret: CoinbaseScript.secret)
        #expect(request.value(forHTTPHeaderField: "CB-ACCESS-SIGN") == expected)
    }

    @Test("AR32: every request the client signs carries a valid HMAC")
    func everySignedRequestIsValid() async throws {
        let transfer = try script.transferCase()
        let order = try script.filledOrder()
        let session = ScriptedSession(order.routes + transfer.scripted.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        _ = try await client.placeOrder(market: script.market, side: order.side, size: order.size, limit: order.limit, immediateOrCancel: true, reduceOnly: false, account: script.account)
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        let signed = session.requests.filter { $0.value(forHTTPHeaderField: "CB-ACCESS-SIGN") != nil }
        #expect(signed.count >= 2)
        for request in signed {
            #expect(request.value(forHTTPHeaderField: "CB-ACCESS-SIGN") == (try Self.expectedSign(for: request, secret: CoinbaseScript.secret)))
        }
    }

    @Test("C31: the account's own portfolios are the two ends of a transfer (T103)")
    func transferNamesBothPortfolios() async throws {
        let transfer = try script.transferCase()
        let session = ScriptedSession(transfer.scripted.routes)
        let client = try script.makeClient(session: session, log: LogCapture())
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        let request = try #require(session.requests.first { ScriptedSession.urlAndBody(of: $0).contains("move_funds") })
        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        #expect(body.contains(CoinbaseScript.reserve))
        #expect(body.contains(CoinbaseScript.portfolio))
        #expect(request.httpMethod == "POST")
    }
}
