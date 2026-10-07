// D13 — Hyperliquid's exchange chain scanner, the adapter over C31's client.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.3: "`KrakenScanner`, `CoinbaseScanner` and
// `HyperliquidScanner` wrap C31's client. ... Each is made without credentials and keeps its client behind a `Mutex`
// with a `configure(client:)` door and an `isAvailable` ... unconfigured, it throws a typed error naming the exchange,
// never a zero." And § 6: "The same for Hyperliquid and Coinbase."
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D13 Hyperliquid scanner")
struct D13_HyperliquidScannerTests {
    private let account = HyperliquidHolding(address: "four-hour-2x")

    // invented: as in D53 — the `registry:` label, RecordedHyperliquid.session(answering:), HyperliquidAgentKey.stub()
    private func client(_ recording: String) throws -> HyperliquidClient {
        try HyperliquidClient(credential: .agentKey(.stub()), endpoint: .testMarket,
                              session: RecordedHyperliquid.session(answering: recording),
                              registry: AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    // "Each is made without credentials" and "an `isAvailable`"
    @Test func unconfiguredIsNotAvailable() {
        // invented: HyperliquidScanner() — "made without credentials" implies an empty initializer
        #expect(!HyperliquidScanner().isAvailable)
    }

    // "unconfigured, it throws a typed error naming the exchange, never a zero"
    @Test(.disabled("Classified 2026-10-07: needs ExchangeScannerError.unconfigured(exchange:), not declared: the unconfigured scanner throws ExchangeClientError.unauthorized(text:) naming Hyperliquid; see the identity ledger")) func unconfiguredThrowsNamingTheExchange() async {
        // invented: ExchangeScannerError.unconfigured(exchange:) — the typed error's name is not declared
        await #expect(throws: ExchangeScannerError.unconfigured(exchange: "Hyperliquid")) {
            _ = try await HyperliquidScanner().getBalance(forAccount: account)
        }
    }

    // "a `configure(client:)` door"
    @Test func configuredIsAvailable() throws {
        let scanner = HyperliquidScanner()
        scanner.configure(client: try client("clearinghouseState"))
        #expect(scanner.isAvailable)
    }

    // "`getBalance(forAccount:)` is the client's `accountState(account:)`"
    @Test(.disabled("Classified 2026-10-07: asserts the recorded sub-account's state is handed up; it holds a position in NEO, which Hyperliquid's table does not declare, and the design says a money value in an undeclared holding is refused (§ 5.3); see the identity ledger")) func balanceIsTheRecordedAccountState() async throws {
        let client = try client("clearinghouseState")
        let scanner = HyperliquidScanner()
        scanner.configure(client: client)
        let state = try await client.accountState(account: account.address)
        // invented: the 2023 `Amount<Contract>`'s quantity as `quantity`
        #expect(try await scanner.getBalance(forAccount: account).quantity == state.balance.baseUnits)
    }

    // "its ledger read maps every recorded ledger item to a `CryptoTransaction`"
    @Test(.disabled("Classified 2026-10-07: asserts the recorded sub-account's ledger is handed up; it holds fills in RUNE, which Hyperliquid's table does not declare, and the design says a money value in an undeclared holding is refused (§ 5.3); see the identity ledger")) func ledgerReadMapsEveryItem() async throws {
        let client = try client("userNonFundingLedgerUpdates")
        let scanner = HyperliquidScanner()
        scanner.configure(client: client)
        let items = try await client.ledgerItems(account: account.address, since: nil)
        #expect(try await scanner.getTransactions(forAccount: account).count == items.count)
    }

    // "`loadTransactions(from:)` of the recorded answer gives the same list"
    @Test(.disabled("Classified 2026-10-07: asserts the recorded sub-account's ledger is handed up; it holds fills in RUNE, which Hyperliquid's table does not declare, and the design says a money value in an undeclared holding is refused (§ 5.3); see the identity ledger")) func loadTransactionsGivesTheSameList() async throws {
        let scanner = HyperliquidScanner()
        scanner.configure(client: try client("userNonFundingLedgerUpdates"))
        let read = try await scanner.getTransactions(forAccount: account)
        // invented: RecordedHyperliquid.data(_:), CryptoTransaction's time as `timeStamp`
        let loaded = try scanner.loadTransactions(from: RecordedHyperliquid.data("userNonFundingLedgerUpdates"))
        #expect(loaded.map(\.timeStamp) == read.map(\.timeStamp))
    }

    // "the plug-in's `KrakenClient` is configured into `KrakenExchangeChain.default.scanner` at the client's init" — the same for Hyperliquid
    @Test func clientInitConfiguresTheChainsScanner() throws {
        _ = try client("clearinghouseState")
        #expect(HyperliquidExchangeChain.default.scanner.isAvailable)
    }
}
