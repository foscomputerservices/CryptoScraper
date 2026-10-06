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

    static func price(_ text: String) -> Price {
        try! WireDecimal(parsing: text).price(of: .usd, per: .btc)
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
        #expect(throws: CoinbaseClientError.malformedCredential) { try CoinbaseCredential(keyName: "k", privateKeyPEM: "not a key") }
    }

    @Test func theMarketsAreTheProductsAtTheirIncrementsDecimals() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let markets = try await Coinbase.client(session).markets()
        let btcusd = try #require(markets.first { $0.name == Coinbase.btcusd })
        #expect(btcusd.base == .btc && btcusd.quote == .usd)
        #expect(btcusd.lotSize == Amount(baseUnits: 1, asset: .btc))
        #expect(btcusd.minimumOrder == Amount(baseUnits: 1, asset: .btc))
        #expect(!btcusd.isPerpetual && btcusd.maxLeverage == nil)
        let perp = try #require(markets.first { $0.name == (try! CoinbaseMarketName(validating: "BTC-PERP-INTX")) })
        #expect(perp.isPerpetual && perp.maxLeverage == 50)
        #expect(perp.base == (try Asset(symbol: "BTC", unitExponent: 4)))
    }

    @Test func theBookIsTheExchangesBestBidAskMidAndDayVolume() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let book = try await Coinbase.client(session).orderBook(market: Coinbase.btcusd)
        #expect(book.bestBid == Coinbase.price("85559.66"))
        #expect(book.bestAsk == Coinbase.price("85559.67"))
        #expect(book.mid == Coinbase.price("85559.665"))
        #expect(book.volume == (try WireDecimal(parsing: "4586.69588742").amount(of: .btc)))
        #expect(book.readAt.timeIntervalSince1970 > 1_791_273_036)
    }

    @Test func anOrderIsCreatedThenReadForItsFill() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let size = try WireDecimal(parsing: "0.001").amount(of: .btc)
        let result = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .buy, size: size, limit: Coinbase.price("10000"),
                                                                    immediateOrCancel: true, reduceOnly: false, account: "")
        // The documented order: filled_size "0.001" at average_filled_price "50", last fill 2021-05-31T09:59:59Z.
        #expect(result == .filled(units: size, at: Coinbase.price("50"), id: try CoinbaseOrderId(validating: "11111-00000-000000"),
                                  time: Date(timeIntervalSince1970: 1_622_455_199)))
        let created = try #require(session.requests.first { $0.httpMethod == "POST" })
        let configuration = try #require(created.jsonBody["order_configuration"] as? [String: [String: String]])
        #expect(configuration == ["sor_limit_ioc": ["base_size": "0.001", "limit_price": "10000"]])
        #expect(created.jsonBody["side"] as? String == "BUY")
    }

    @Test func aRefusedOrderIsCoinbasesWords() async throws {
        let session = ReplaySession(route: Coinbase.route(["/orders": .ok(Recording.body("Coinbase/private-create-order-failure.json"))]))
        let result = try await Coinbase.client(session).placeOrder(market: Coinbase.btcusd, side: .sell, size: Amount(baseUnits: 1, asset: .btc), limit: Coinbase.price("1"),
                                                                    immediateOrCancel: true, reduceOnly: true, account: "")
        #expect(result == .refused(code: "UNKNOWN_FAILURE_REASON", text: "The order configuration was invalid"))
    }

    @Test func anErrorBodyIsCoinbasesTypedError() async throws {
        let session = ReplaySession(route: Coinbase.route(["/key_permissions": Reply(status: 403, body: Recording.body("Coinbase/private-error.json"), headers: [:])]))
        await #expect(throws: CoinbaseAPIError(code: "PERMISSION_DENIED", message: "Target Account Not Tradable")) {
            try await Coinbase.client(session).keyFacts()
        }
    }

    @Test func a429IsTheTypedLimit() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "2"]) }
        await #expect(throws: CoinbaseLimitError(retryAfter: .seconds(2), apiError: nil)) {
            try await Coinbase.client(session).markets()
        }
    }

    @Test func theOpenOrdersAreTheirRemainingUnits() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let open = try await Coinbase.client(session).openOrders(account: "")
        #expect(open.first?.units == .zero(of: .btc)) // base_size "0.001", filled "0.001"
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
        #expect(state.balance == Amount(baseUnits: 246, asset: .usd))
        #expect(state.withdrawable == Amount(baseUnits: 123, asset: .usd))
        #expect(state.positions.isEmpty)
        #expect(state.mode.name == "UNDEFINED")
    }

    @Test func theLedgerIsTheFillsWithTheirCommissionAndCursor() async throws {
        // The documented page's cursor "789100" names a next page; a recording answers every page alike, so the
        // client stops when the cursor comes back unchanged and reads the one fill twice. One page here, cursor "".
        let onePage = String(decoding: Recording.body("Coinbase/private-list-fills.json"), as: UTF8.self).replacingOccurrences(of: "789100", with: "")
        let session = ReplaySession(route: Coinbase.route(["/orders/historical/fills": .ok(Data(onePage.utf8))]))
        let items = try await Coinbase.client(session).ledgerItems(account: "", since: nil)
        guard case .fill(let market, let side, let units, let price, let fee, let order, _, _, let cursor) = try #require(items.first) else {
            Issue.record("Not a fill")
            return
        }
        #expect(market == Coinbase.btcusd && side == .buy)
        #expect(units == (try WireDecimal(parsing: "0.001").amount(of: .btc)))
        #expect(price == Coinbase.price("10000"))
        #expect(fee == (try WireDecimal(parsing: "1.25").amount(of: .usd)))
        #expect(order == (try CoinbaseOrderId(validating: "0000-000000-000000")))
        #expect(try cursor.toJSON().fromJSON() == cursor)
        #expect(items.count == 1)
    }

    @Test func aTransferMovesFundsBetweenTwoPortfolios() async throws {
        let session = ReplaySession(route: Coinbase.route())
        try await Coinbase.client(session).transfer(Amount(baseUnits: 50_025, asset: .usd), from: "portfolio-a", to: "portfolio-b")
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
        await #expect(throws: CoinbaseClientError.leverageNotSettable) { try await client.setLeverage(2, market: Coinbase.btcusd, isolated: true, account: "") }
        #expect(!client.hasTestMarket)
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
