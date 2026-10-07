// CoinbaseClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// § 8.6 for Coinbase Advanced Trade's exchange client: the public reads recorded read-only on 2026-10-06; the private
// answers built from Coinbase's documented response schemas (no Coinbase account exists here), each marked
// documentation-derived in its header; the JWT verified with the key's public half.

enum Coinbase {
    static let btcusd = try! CoinbaseMarketName(validating: "BTC-USD")
    // Coinbase's declared holdings (step 4b of the identity PR), declared in the shared registry before any amount is
    // made in them, whichever test runs first
    static let btc: AssetInstance = declared(CoinbaseHolding.btc)
    static let usd: AssetInstance = declared(CoinbaseHolding.usd)
    static let key = P256.Signing.PrivateKey()
    static let credential = try! CoinbaseCredential(keyName: "organizations/fred/apiKeys/barney", privateKeyPEM: key.pemRepresentation)
    static let now = Date(timeIntervalSince1970: 1_791_273_036)

    static func route(_ overrides: [String: Reply] = [:]) -> @Sendable (URLRequest, Int) -> Reply {
        { request, _ in
            let path = request.url!.path
            if let reply = overrides.first(where: { path.hasSuffix($0.key) })?.value { return reply }
            let file: String = switch true {
            case path.hasSuffix("/market/products"): "products.json"
            case path.hasSuffix("/market/products/BTC-USD"): "product-btc-usd.json"
            case path.hasSuffix("/market/product_book"): "product-book-btc-usd.json"
            case path.hasSuffix("upcoming.json"): "maintenances-upcoming.json"
            case path.hasSuffix("/orders") && request.httpMethod == "POST": "private-create-order-success.json"
            case path.hasSuffix("/orders/historical/batch"): "private-list-orders-open.json"
            case path.contains("/orders/historical/fills"): "private-list-fills.json"
            case path.contains("/orders/historical/"): "private-get-order.json"
            case path.hasSuffix("/orders/batch_cancel"): "private-cancel-orders.json"
            case path.hasSuffix("/accounts"): "private-list-accounts.json"
            case path.hasSuffix("/key_permissions"): "private-key-permissions.json"
            case path.hasSuffix("/portfolios/move_funds"): "private-move-funds.json"
            default: "none"
            }
            return .ok(Recording.body("Coinbase/\(file)"))
        }
    }

    static func client(_ session: ReplaySession) -> CoinbaseClient {
        CoinbaseClient(credential: credential, session: session, now: { now })
    }

    static func declared(_ holding: CoinbaseHolding) -> AssetInstance {
        do {
            try CoinbaseExchangeChain.declare(in: .shared)
        } catch {
            preconditionFailure("Coinbase's declarations conflict with the shared registry: \(error)")
        }
        return AssetInstance(holding)
    }

    static func price(_ text: String) -> Price {
        try! WireDecimal(parsing: text).price(of: usd, per: btc)
    }
}

@Suite("Coinbase exchange client")
struct CoinbaseClientTests {
    @Test func aPrivateRequestCarriesAJWTSignedES256ForItsOwnMethodHostAndPath() async throws {
        let session = ReplaySession(route: Coinbase.route())
        _ = try await Coinbase.client(session).keyFacts()
        let authorization = try #require(session.requests.last?.value(forHTTPHeaderField: "Authorization"))
        let token = try #require(authorization.split(separator: " ").last)
        let parts = token.split(separator: ".").map(String.init)
        #expect(parts.count == 3)

        func decoded(_ part: String) throws -> [String: Any] {
            var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
            let data = try #require(Data(base64Encoded: base64))
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let header = try decoded(parts[0])
        let claims = try decoded(parts[1])
        #expect(header["alg"] as? String == "ES256" && header["kid"] as? String == "organizations/fred/apiKeys/barney")
        #expect(claims["iss"] as? String == "cdp" && claims["sub"] as? String == "organizations/fred/apiKeys/barney")
        #expect(claims["uri"] as? String == "GET api.coinbase.com/api/v3/brokerage/key_permissions")
        #expect((claims["nbf"] as? NSNumber)?.int64Value == 1_791_273_036 && (claims["exp"] as? NSNumber)?.int64Value == 1_791_273_156)

        var signature = parts[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        signature += String(repeating: "=", count: (4 - signature.count % 4) % 4)
        let signatureBytes = try #require(Data(base64Encoded: signature))
        let raw = try P256.Signing.ECDSASignature(rawRepresentation: signatureBytes)
        #expect(Coinbase.key.publicKey.isValidSignature(raw, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    @Test func aPublicReadCarriesNoToken() async throws {
        let session = ReplaySession(route: Coinbase.route())
        _ = try await CoinbaseClient(credential: nil, session: session).markets()
        #expect(session.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }

    @Test func theCredentialNamesNeitherItsKeyNameNorItsKey() {
        for text in [Coinbase.credential.description, String(reflecting: Coinbase.credential), "\(Coinbase.credential)"] {
            #expect(!text.contains("barney") && !text.contains("PRIVATE KEY"))
        }
        #expect(throws: ExchangeClientError.unauthorized(text: "A Coinbase key name and its P-256 private key in PEM are both needed")) { try CoinbaseCredential(keyName: "k", privateKeyPEM: "not a key") }
    }

    // Carried in step 4b of the identity PR: the product's holdings are Coinbase's declared constants, no longer assets
    // made from its currency ids at its increments' places; the increments are the lot and the minimum, in the base.
    @Test func theMarketsAreTheProductsAtTheirIncrementsDecimals() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let markets = try await Coinbase.client(session).markets()
        let btcusd = try #require(markets.first { $0.name == Coinbase.btcusd })
        #expect(btcusd.base == Coinbase.btc && btcusd.quote == Coinbase.usd)
        #expect(btcusd.lotSize == Amount(baseUnits: 1, of: Coinbase.btc))
        #expect(btcusd.minimumOrder == Amount(baseUnits: 1, of: Coinbase.btc))
        #expect(!btcusd.isPerpetual && btcusd.maxLeverage == nil)
        let perp = try #require(markets.first { $0.name == (try! CoinbaseMarketName(validating: "BTC-PERP-INTX")) })
        #expect(perp.isPerpetual && perp.maxLeverage == 50)
        #expect(perp.base == Coinbase.btc && perp.lotSize == Amount(baseUnits: 10_000, of: Coinbase.btc))
    }

    @Test func theBookIsTheExchangesBestBidAskMidAndDayVolume() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let book = try await Coinbase.client(session).orderBook(market: Coinbase.btcusd)
        #expect(book.bestBid == Coinbase.price("85559.66"))
        #expect(book.bestAsk == Coinbase.price("85559.67"))
        #expect(book.mid == Coinbase.price("85559.665"))
        #expect(book.baseVolume == (try WireDecimal(parsing: "4586.69588742").amount(of: Coinbase.btc)))
        #expect(book.quoteVolume == (try WireDecimal(parsing: "392436140.65").amount(of: Coinbase.usd)))  // approximate_quote_24h_volume
        #expect(book.readAt.timeIntervalSince1970 > 1_791_273_036)
    }

    @Test func aProductWithNoStatedTurnoverHasItsBaseVolumePricedAtTheMid() async throws {
        let product = String(decoding: Recording.body("Coinbase/product-btc-usd.json"), as: UTF8.self)
            .replacingOccurrences(of: #""approximate_quote_24h_volume":"392436140.65""#, with: #""approximate_quote_24h_volume":"""#)
        let session = ReplaySession(route: Coinbase.route(["/market/products/BTC-USD": .ok(Data(product.utf8))]))
        let book = try await Coinbase.client(session).orderBook(market: Coinbase.btcusd)
        // 4586.69588742 × 85559.665, cut toward zero at USD's two digits
        #expect(book.quoteVolume == (try WireDecimal(parsing: "392436163.58").amount(of: Coinbase.usd)))
    }

    @Test func anOrderIsCreatedThenReadForItsFill() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let size = try WireDecimal(parsing: "0.001").amount(of: Coinbase.btc)
        let result = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .buy, size: size, limit: Coinbase.price("10000"),
                                                                    immediateOrCancel: true, reduceOnly: false, clientOrderId: nil, account: "")
        // The documented order: filled_size "0.001" at average_filled_price "50", last fill 2021-05-31T09:59:59Z.
        #expect(result == .filled(units: size, at: Coinbase.price("50"), id: try CoinbaseOrderId(validating: "11111-00000-000000"),
                                  time: Date(timeIntervalSince1970: 1_622_455_199)))
        let created = try #require(session.requests.first { $0.httpMethod == "POST" })
        let configuration = try #require(created.jsonBody["order_configuration"] as? [String: [String: String]])
        #expect(configuration == ["sor_limit_ioc": ["base_size": "0.001", "limit_price": "10000"]])
        #expect(created.jsonBody["side"] as? String == "BUY")
    }

    @Test func anOpenOrderWithNothingFilledIsResting() async throws {
        let read = String(decoding: Recording.body("Coinbase/private-get-order.json"), as: UTF8.self)
            .replacingOccurrences(of: #""status": "PENDING""#, with: #""status": "OPEN""#)
            .replacingOccurrences(of: #""filled_size": "0.001""#, with: #""filled_size": "0""#)
        let session = ReplaySession(route: Coinbase.route(["/orders/historical/11111-00000-000000": .ok(Data(read.utf8))]))
        let result = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .buy, size: Amount(baseUnits: 100_000, of: Coinbase.btc), limit: Coinbase.price("10000"),
                                                                    immediateOrCancel: false, reduceOnly: false, clientOrderId: nil, account: "")
        guard case let .resting(id, _) = result else { Issue.record("not resting: \(result)"); return }
        #expect(id == (try CoinbaseOrderId(validating: "11111-00000-000000")))
    }

    @Test func aRefusedOrderIsCoinbasesWords() async throws {
        let session = ReplaySession(route: Coinbase.route(["/orders": .ok(Recording.body("Coinbase/private-create-order-failure.json"))]))
        let result = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .sell, size: Amount(baseUnits: 1, of: Coinbase.btc), limit: Coinbase.price("1"),
                                                                    immediateOrCancel: true, reduceOnly: true, clientOrderId: nil, account: "")
        #expect(result == .refused(code: "UNKNOWN_FAILURE_REASON", text: "The order configuration was invalid"))
    }

    @Test func anErrorBodyIsRefusedWithCoinbasesCodeAndMessage() async throws {
        let session = ReplaySession(route: Coinbase.route(["/key_permissions": Reply(status: 403, body: Recording.body("Coinbase/private-error.json"), headers: [:])]))
        #expect(await sharedError { try await Coinbase.client(session).keyFacts() } == .refused(code: "PERMISSION_DENIED", text: "Target Account Not Tradable"))
    }

    @Test func aStatus401IsUnauthorizedWithCoinbasesWords() async throws {
        let session = ReplaySession { _, _ in Reply(status: 401, body: Data(#"{"error":"unauthorized","message":"Unauthorized"}"#.utf8), headers: [:]) }
        #expect(await sharedError { try await Coinbase.client(session).accountState(account: "") } == .unauthorized(text: "Unauthorized"))
    }

    @Test func a429WithRetryAfterIsRateLimitedWithItsWait() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "2"]) }
        #expect(await sharedError { try await Coinbase.client(session).markets() } == .rateLimited(retryAfter: .seconds(2)))
    }

    @Test func aMalformedBodyIsMalformedResponseNeverAValue() async throws {
        let session = ReplaySession { _, _ in .ok(Data(#"{"products":[{"product_id":"BTC-USD","price":"eighty"}]}"#.utf8)) }
        #expect(await sharedError { try await Coinbase.client(session).markets() }?.meaning == "malformedResponse")
    }

    @Test func noAnswerIsUnreachableWithTheTransportsText() async throws {
        let session = ReplaySession { _, _ in .failing(URLError(.notConnectedToInternet)) }
        #expect(await sharedError { try await Coinbase.client(session).markets() } == .unreachable(text: URLError(.notConnectedToInternet).localizedDescription))
    }

    @Test func theOpenOrdersAreTheirRemainingUnits() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let open = try await Coinbase.client(session).openOrders(account: "")
        #expect(open.first?.units == .zero(of: Coinbase.btc)) // base_size "0.001", filled "0.001"
        #expect(open.first?.side == .buy)
    }

    @Test func aCancelIsCoinbasesResult() async throws {
        let session = ReplaySession(route: Coinbase.route())
        try await Coinbase.client(session).cancelOrder(try CoinbaseOrderId(validating: "0000-00000"), market: Coinbase.btcusd, account: "")
        #expect(session.requests.last!.jsonBody["order_ids"] as? [String] == ["0000-00000"])
    }

    @Test func theAccountStateIsTheUSDWalletAndTheKeysPortfolioType() async throws {
        // The documented account is a BTC wallet; this one is the same shape for USD, made here, on one page.
        let usdWallet = #"{"accounts":[{"uuid":"8bfc20d7-f7c6-4422-bf07-8243ca4169fe","name":"USD Wallet","currency":"USD","available_balance":{"value":"1.23","currency":"USD"},"hold":{"value":"1.23","currency":"USD"}}],"has_next":false,"cursor":"","size":1}"#
        let session = ReplaySession(route: Coinbase.route(["/accounts": .ok(Data(usdWallet.utf8))]))
        let state = try await Coinbase.client(session).accountState(account: "")
        #expect(state.balance == Amount(baseUnits: 246, of: Coinbase.usd))
        #expect(state.withdrawable == Amount(baseUnits: 123, of: Coinbase.usd))
        #expect(state.positions.isEmpty)
        #expect(state.mode.name == "UNDEFINED")
    }

    @Test func theLedgerIsTheFillsWithTheirCommissionAndCursor() async throws {
        // The documented page's cursor "789100" names a next page; a recording answers every page alike, so the
        // client stops when the cursor comes back unchanged and reads the one fill twice. One page here, cursor "".
        let onePage = String(decoding: Recording.body("Coinbase/private-list-fills.json"), as: UTF8.self).replacingOccurrences(of: "789100", with: "")
        let session = ReplaySession(route: Coinbase.route(["/orders/historical/fills": .ok(Data(onePage.utf8))]))
        let items = try await Coinbase.client(session).ledgerItems(account: "", since: nil)
        guard case .fill(let market, let side, let units, let price, let fee, let order, _, _, let cursor, _) = try #require(items.first) else {
            Issue.record("Not a fill")
            return
        }
        #expect(market == Coinbase.btcusd && side == .buy)
        #expect(units == (try WireDecimal(parsing: "0.001").amount(of: Coinbase.btc)))
        #expect(price == Coinbase.price("10000"))
        #expect(fee == (try WireDecimal(parsing: "1.25").amount(of: Coinbase.usd)))
        #expect(order == (try CoinbaseOrderId(validating: "0000-000000-000000")))
        #expect(try cursor.toJSON().fromJSON() == cursor)
        #expect(items.count == 1)
    }

    // List Fills states no position effect (the documented schema, the recording built from it, has side and
    // future_legs, nothing that opens or closes), so a Coinbase fill carries nil.
    @Test func aFillStatesNoPositionEffect() async throws {
        let onePage = String(decoding: Recording.body("Coinbase/private-list-fills.json"), as: UTF8.self).replacingOccurrences(of: "789100", with: "")
        let session = ReplaySession(route: Coinbase.route(["/orders/historical/fills": .ok(Data(onePage.utf8))]))
        let items = try await Coinbase.client(session).ledgerItems(account: "", since: nil)
        guard case .fill(_, _, _, _, _, _, _, _, _, let effect) = try #require(items.first) else {
            Issue.record("Not a fill")
            return
        }
        #expect(effect == nil)
    }

    @Test func aTransferMovesFundsBetweenTwoPortfolios() async throws {
        let session = ReplaySession(route: Coinbase.route())
        try await Coinbase.client(session).transfer(Amount(baseUnits: 50_025, of: Coinbase.usd), from: "portfolio-a", to: "portfolio-b")
        let body = session.requests.last!.jsonBody
        #expect(body["funds"] as? [String: String] == ["value": "500.25", "currency": "USD"])
        #expect(body["source_portfolio_uuid"] as? String == "portfolio-a" && body["target_portfolio_uuid"] as? String == "portfolio-b")
    }

    @Test func theKeyFactsAreCoinbasesPermissions() async throws {
        let session = ReplaySession(route: Coinbase.route())
        #expect(try await Coinbase.client(session).keyFacts()
            == ExchangeClientKeyFacts(canTrade: false, canTransfer: false, canWithdraw: false, approvedBy: nil, validUntil: nil))
    }

    @Test func leverageIsNotSettableAndThereIsNoTestMarket() async throws {
        let client = Coinbase.client(ReplaySession(route: Coinbase.route()))
        await #expect(throws: ExchangeClientError.notOffered(member: "setLeverage")) { try await client.setLeverage(2, market: Coinbase.btcusd, isolated: true, account: "") }
        #expect(!client.hasTestMarket)
    }

    @Test func aWindowIsClassifiedByItsNameAndComponentsAndAnythingUnrecognisedIsOther() async throws {
        // constructed in the Statuspage shape of the recording (none was scheduled on 2026-10-06); only the words differ
        func page(_ name: String, _ components: [String]) -> String {
            let parts = components.map { "{\"name\":\"\($0)\"}" }.joined(separator: ",")
            return "{\"name\":\"\(name)\",\"scheduled_for\":\"2026-10-12T18:00:00.000Z\",\"scheduled_until\":\"2026-10-12T19:00:00.000Z\",\"components\":[\(parts)],\"incident_updates\":[]}"
        }
        let body = "{\"scheduled_maintenances\":[" + [
            page("Advanced Trade maintenance", ["Advanced Trade"]),
            page("Withdrawals delayed", ["Sends"]),
            page("Wallet", ["Deposits & Withdrawals"]),
            page("Coinbase.com update", ["Website"]),
        ].joined(separator: ",") + "]}"
        let client = Coinbase.client(ReplaySession(route: Coinbase.route(["upcoming.json": .ok(Data(body.utf8))])))
        let windows = try await client.maintenanceWindows()
        #expect(windows.map(\.subject) == [.trading, .transfers, .transfers, .other])
        #expect(windows[0].text == "Advanced Trade maintenance")
    }

    @Test func theBudgetMaintenanceAndNotices() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let client = Coinbase.client(session)
        #expect(try await client.maintenanceWindows().isEmpty) // none scheduled on 2026-10-06
        let notices = try await client.notices()
        #expect(notices.map(\.market) == [try CoinbaseMarketName(validating: "BTC-PERP-INTX")]) // trading_disabled here
        let budget = try await client.requestBudget()
        #expect(budget.limit == 10_000 && budget.remaining == 10_000 - session.requests.count + 1) // the status page is not Coinbase's API
    }

    @Test func anOrderIdAndACursorRoundTripThroughJSON() throws {
        let id = try CoinbaseOrderId(validating: "11111-00000-000000")
        #expect(try id.toJSON().fromJSON() == id)
        let cursor = try CoinbaseLedgerCursor(sequenceTimestamp: "2026-10-06T07:50:36.589181Z")
        #expect(try cursor.toJSON().fromJSON() == cursor)
    }
}

// The client gaps of the identity PR (fosline's layer B ledger § 6): the client order id, and the account state of a
// portfolio other than the key's own.
@Suite("Coinbase exchange client: the client gaps")
struct CoinbaseClientGapsTests {
    static let token: UInt128 = 0x6d1b_345e_2821_40e2_ad83_4ecb_18a0_6876

    @Test func theClientOrderIdIsSentAsClientOrderIdInAUUIDsForm() async throws {
        let session = ReplaySession(route: Coinbase.route())
        _ = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .buy, size: try WireDecimal(parsing: "0.001").amount(of: Coinbase.btc),
                                                          limit: Coinbase.price("10000"), immediateOrCancel: true, reduceOnly: false,
                                                          clientOrderId: Self.token, account: "")
        let created = try #require(session.requests.first { $0.httpMethod == "POST" })
        #expect(created.jsonBody["client_order_id"] as? String == "6d1b345e-2821-40e2-ad83-4ecb18a06876")
    }

    // Coinbase requires client_order_id: with none given the client still sends one of its own, a fresh UUID.
    @Test func noClientOrderIdSendsAFreshOne() async throws {
        let session = ReplaySession(route: Coinbase.route())
        for _ in 0..<2 {
            _ = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .buy, size: try WireDecimal(parsing: "0.001").amount(of: Coinbase.btc),
                                                              limit: Coinbase.price("10000"), immediateOrCancel: true, reduceOnly: false,
                                                              clientOrderId: nil, account: "")
        }
        let sent = session.requests.filter { $0.httpMethod == "POST" }.compactMap { $0.jsonBody["client_order_id"] as? String }
        #expect(sent.count == 2 && sent[0] != sent[1] && sent.allSatisfy { UUID(uuidString: $0) != nil })
    }

    // The documented open order's client_order_id, "11111-000000-000000", is the schema's example, not 128 bits in a
    // UUID's form: it is handed back as none. A UUID's form reads back.
    @Test func anOpenOrdersClientOrderIdIsHandedBackWhereItIsAUUIDsForm() async throws {
        let recorded = try await Coinbase.client(ReplaySession(route: Coinbase.route())).openOrders(account: "")
        #expect(recorded.count == 1 && recorded.allSatisfy { $0.clientOrderId == nil })
        let listed = String(decoding: Recording.body("Coinbase/private-list-orders-open.json"), as: UTF8.self)
            .replacingOccurrences(of: "11111-000000-000000", with: "6D1B345E-2821-40E2-AD83-4ECB18A06876")
        let session = ReplaySession(route: Coinbase.route(["/orders/historical/batch": .ok(Data(listed.utf8))]))
        #expect(try await Coinbase.client(session).openOrders(account: "").map(\.clientOrderId) == [Self.token])
    }

    // Coinbase's account reads are the key's own portfolio, whose uuid key_permissions states: another portfolio's
    // state is refused, naming it, and never answered with the key's own.
    @Test func anotherPortfoliosStateIsRefusedNamingIt() async throws {
        let permissions = #"{"can_view":true,"can_trade":true,"can_transfer":false,"portfolio_uuid":"8bfc20d7-0000-4000-8000-000000000001","portfolio_type":"DEFAULT"}"#
        let session = ReplaySession(route: Coinbase.route(["/key_permissions": .ok(Data(permissions.utf8))]))
        let error = await sharedError { try await Coinbase.client(session).accountState(account: "8bfc20d7-0000-4000-8000-000000000002") }
        #expect(error == .refused(code: nil, text: "Coinbase reads only the key's own portfolio, 8bfc20d7-0000-4000-8000-000000000001, not 8bfc20d7-0000-4000-8000-000000000002"))
        #expect(!session.requests.contains { $0.url!.path.hasSuffix("/accounts") })
    }

    @Test func theKeysOwnPortfoliosStateIsRead() async throws {
        let permissions = #"{"can_view":true,"can_trade":true,"can_transfer":false,"portfolio_uuid":"8bfc20d7-0000-4000-8000-000000000001","portfolio_type":"DEFAULT"}"#
        let session = ReplaySession(route: Coinbase.route(["/key_permissions": .ok(Data(permissions.utf8))]))
        let state = try await Coinbase.client(session).accountState(account: "8bfc20d7-0000-4000-8000-000000000001")
        #expect(state.mode.name == "DEFAULT")
    }
}
