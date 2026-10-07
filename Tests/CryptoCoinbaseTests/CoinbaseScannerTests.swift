// CoinbaseScannerTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// Design § 1.3 "Never nil" and § 6 "The exchange scanners" and "The table, per plug-in", for Coinbase: the scanner
// configured over a client whose answers are the recordings, the client's declarations and its units check, and the
// recorded listing through the table. Each scanner is made fresh, so no test reads another's configuration.

@Suite("Coinbase's scanner and holdings")
struct CoinbaseScannerTests {
    static let btc = AssetInstance(CoinbaseHolding.btc)
    static let usd = AssetInstance(CoinbaseHolding.usd)

    // The documented accounts answer is a BTC wallet; this one is the same shape for USD, made here, on one page, as
    // the client's own account-state test makes it.
    static let usdWallet = #"{"accounts":[{"uuid":"8bfc20d7-f7c6-4422-bf07-8243ca4169fe","name":"USD Wallet","currency":"USD","available_balance":{"value":"1.23","currency":"USD"},"hold":{"value":"1.23","currency":"USD"}}],"has_next":false,"cursor":"","size":1}"#

    // The documented fills page names a next page by "789100"; one page here, cursor "".
    static var onePageOfFills: Data {
        Data(String(decoding: Recording.body("Coinbase/private-list-fills.json"), as: UTF8.self).replacingOccurrences(of: "789100", with: "").utf8)
    }

    // Carried in the client gaps of the identity PR: Coinbase reads only the key's own portfolio and refuses another,
    // so the documented key permissions name the portfolio these tests read as the key's own.
    static var keysOwnPortfolio: Data {
        Data(String(decoding: Recording.body("Coinbase/private-key-permissions.json"), as: UTF8.self)
            .replacingOccurrences(of: #""portfolio_uuid": """#, with: #""portfolio_uuid": "\#(portfolio.address)""#).utf8)
    }

    static func configured() -> CoinbaseScanner {
        let scanner = CoinbaseScanner()
        let route = Coinbase.route(["/accounts": .ok(Data(usdWallet.utf8)), "/orders/historical/fills": .ok(onePageOfFills),
                                    "/key_permissions": .ok(keysOwnPortfolio)])
        scanner.configure(client: Coinbase.client(ReplaySession(route: route)))
        return scanner
    }

    static let portfolio = CoinbaseHolding(address: "8bfc20d7-f7c6-4422-bf07-8243ca4169fe")

    // MARK: The scanner over the recordings

    @Test func aConfiguredScannerIsAvailable() {
        #expect(Self.configured().isAvailable)
    }

    @Test func theClientConfiguresItselfIntoTheChainsScanner() {
        _ = Coinbase.client(ReplaySession(route: Coinbase.route()))
        #expect(CoinbaseExchangeChain.default.scanner.isAvailable)
    }

    @Test func theBalanceIsTheRecordedAccountStatesBalance() async throws {
        let balance = try await Self.configured().getBalance(forAccount: Self.portfolio)
        // The USD wallet: "1.23" available and "1.23" held, in Coinbase's dollar at two places
        #expect(balance.quantity == 246)
        #expect(balance.currency == CoinbaseHolding.usd)
    }

    @Test func theDollarsBalanceIsTheAccountsBalance() async throws {
        let balance = try await Self.configured().getBalance(forToken: .usd, forAccount: Self.portfolio)
        #expect(balance.quantity == 246 && balance.currency == CoinbaseHolding.usd)
    }

    @Test func aCoinsBalanceIsZeroSinceASpotPortfolioHoldsNoPositions() async throws {
        let balance = try await Self.configured().getBalance(forToken: .btc, forAccount: Self.portfolio)
        #expect(balance.quantity == 0 && balance.currency == CoinbaseHolding.btc)
    }

    @Test func theLedgerMapsEachFillToACoinbaseTransaction() async throws {
        let transactions = try await Self.configured().getTransactions(forAccount: Self.portfolio)
        let fills = try #require(transactions as? [CoinbaseTransaction])
        // The documented fill: BTC-USD, size "0.001" at BTC's eight places, order "0000-000000-000000", 2021-05-31T09:59:59Z
        #expect(fills.count == 1)
        let fill = try #require(fills.first)
        #expect(fill.amount.quantity == 100_000 && fill.amount.currency == CoinbaseHolding.btc)
        #expect(fill.transactionId == "0000-000000-000000" && fill.hash == fill.transactionId)
        #expect(fill.timeStamp == Date(timeIntervalSince1970: 1_622_455_199))
        #expect(fill.type == "fill" && fill.successful && fill.fromContract == nil && fill.toContract == nil)
    }

    @Test func loadingTheRecordedTransactionsGivesTheSameList() async throws {
        let scanner = Self.configured()
        let read = try #require(try await scanner.getTransactions(forAccount: Self.portfolio) as? [CoinbaseTransaction])
        let loaded = try #require(try scanner.loadTransactions(from: JSONEncoder().encode(read)) as? [CoinbaseTransaction])
        #expect(loaded == read)
    }

    @Test func theChainsScannerIsCoinbases() {
        #expect(CoinbaseExchangeChain.default.scanner.userReadableName == "Coinbase")
    }

    // MARK: The client's holdings

    @Test func theClientDeclaresCoinbaseInItsRegistry() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        _ = CoinbaseClient(credential: Coinbase.credential, session: ReplaySession(route: Coinbase.route()), registry: registry)
        #expect(try registry.decimals(of: Self.btc) == 8)
        #expect(try registry.asset(of: Self.btc) == .btc)
        #expect(try registry.decimals(of: Self.usd) == 2)
    }

    @Test func everyCurrencyInTheRecordedListingResolvesOrIsAFinding() throws {
        let products = (Recording.json("Coinbase/products.json") as! [String: Any])["products"] as! [[String: Any]]
        let currencies = Set(products.flatMap { [$0["base_currency_id"] as! String, $0["quote_currency_id"] as! String] }.filter { !$0.isEmpty })
        #expect(currencies == ["BTC", "ETH", "USD", "USDC"])
        for currency in currencies.subtracting(["USDC"]) {
            #expect(throws: Never.self) { try CoinbaseExchangeChain.default.contract(for: currency) }
        }
        // The perpetual's USDC states its precision only as a price step: a finding, never a holding minted from the string
        #expect(throws: AssetError.malformedIdentity("USDC")) { try CoinbaseExchangeChain.default.contract(for: "USDC") }
    }

    @Test func aTransfersCurrencyIsTheHoldingsWireName() async throws {
        let session = ReplaySession(route: Coinbase.route())
        try await Coinbase.client(session).transfer(Amount(baseUnits: 50_025, of: Self.usd), from: "portfolio-a", to: "portfolio-b")
        let body = session.requests.last!.jsonBody
        #expect(body["funds"] as? [String: String] == ["value": "500.25", "currency": CoinbaseHolding.usd.wireName])
        try await Coinbase.client(session).transfer(Amount(baseUnits: 1, of: Self.btc), from: "portfolio-a", to: "portfolio-b")
        #expect(session.requests.last!.jsonBody["funds"] as? [String: String] == ["value": "0.00000001", "currency": CoinbaseHolding.btc.wireName])
    }

    @Test func aTransferInNoCoinbaseHoldingIsRefused() async throws {
        let session = ReplaySession(route: Coinbase.route())
        let dollar = try AssetInstance(validating: Asset.usd.id)
        await #expect(throws: ExchangeClientError.wrongAsset) {
            try await Coinbase.client(session).transfer(Amount(baseUnits: 1, of: dollar), from: "portfolio-a", to: "portfolio-b")
        }
    }

    @Test func aRecordedMarketLandsOnBTCAndUSDWithItsIncrementAsItsLot() async throws {
        let markets = try await Coinbase.client(ReplaySession(route: Coinbase.route())).markets()
        let btcusd = try #require(markets.first { $0.name == Coinbase.btcusd })
        #expect(btcusd.base == Self.btc && btcusd.quote == Self.usd)
        #expect(btcusd.baseSymbol.text == "BTC" && btcusd.baseDecimals == 8)
        #expect(btcusd.quoteSymbol.text == "USD" && btcusd.quoteDecimals == 2)
        // base_increment "0.00000001" is the lot, base_min_size "0.00000001" the minimum, both in the base holding
        #expect(btcusd.lotSize == Amount(baseUnits: 1, of: Self.btc))
        #expect(btcusd.minimumOrder == Amount(baseUnits: 1, of: Self.btc))
        // Its alias, "BTC-USDC", settles in another holding: no second name
        #expect(btcusd.alternateName == nil)
    }

    @Test func aPerpetualsUndeclaredQuoteGivesANilQuote() async throws {
        let markets = try await Coinbase.client(ReplaySession(route: Coinbase.route())).markets()
        let perp = try #require(markets.first { $0.name == (try! CoinbaseMarketName(validating: "BTC-PERP-INTX")) })
        #expect(perp.base == Self.btc && perp.quote == nil)
        // base_increment "0.0001": a coarser step than BTC's eight places, which is no finding
        #expect(perp.lotSize == Amount(baseUnits: 10_000, of: Self.btc))
        #expect(perp.quoteSymbol.text == "USDC")
    }

    @Test func aRecordedProductWithAFinerIncrementIsRefusedAsTheUnitsFinding() async throws {
        let products = String(decoding: Recording.body("Coinbase/products.json"), as: UTF8.self)
            .replacingOccurrences(of: #""base_increment":"0.00000001""#, with: #""base_increment":"0.0000000001""#)
        #expect(products.contains(#""base_increment":"0.0000000001""#))
        let session = ReplaySession(route: Coinbase.route(["/market/products": .ok(Data(products.utf8))]))
        let error = await sharedError { try await Coinbase.client(session).markets() }
        guard case .refused(nil, let text) = error else {
            Issue.record("Not the units finding: \(String(describing: error))")
            return
        }
        #expect(text.contains("decimalsChanged") && text.contains("exchange:coinbase:BTC"))
    }
}
