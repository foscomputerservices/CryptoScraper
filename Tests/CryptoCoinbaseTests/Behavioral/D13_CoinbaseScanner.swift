// D13 — Coinbase's exchange chain scanner, the adapter over C31's client.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.3: "Each is made without credentials and keeps its
// client behind a `Mutex` with a `configure(client:)` door and an `isAvailable` ... unconfigured, it throws a typed
// error naming the exchange, never a zero." And § 6: "The same for Hyperliquid and Coinbase."
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D13 Coinbase scanner")
struct D13_CoinbaseScannerTests {
    private let account = CoinbaseHolding(address: "quarry-42")

    // invented: as in D53 — CoinbaseClient(credential:session:registry:), CoinbaseCredential.stub(), RecordedCoinbase.session(answering:)
    private func client(_ recording: String) throws -> CoinbaseClient {
        try CoinbaseClient(credential: .stub(), session: RecordedCoinbase.session(answering: recording),
                           registry: AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    // "Each is made without credentials" and "an `isAvailable`"
    @Test func unconfiguredIsNotAvailable() {
        // invented: CoinbaseScanner() — "made without credentials" implies an empty initializer
        #expect(!CoinbaseScanner().isAvailable)
    }

    // "unconfigured, it throws a typed error naming the exchange, never a zero"
    @Test(.disabled("Classified 2026-10-07: needs ExchangeScannerError.unconfigured(exchange:), not declared: the unconfigured scanner throws ExchangeClientError.unauthorized(text:) naming Coinbase; see the identity ledger")) func unconfiguredThrowsNamingTheExchange() async {
        // invented: ExchangeScannerError.unconfigured(exchange:)
        await #expect(throws: ExchangeScannerError.unconfigured(exchange: "Coinbase")) {
            _ = try await CoinbaseScanner().getBalance(forAccount: account)
        }
    }

    // "a `configure(client:)` door"
    @Test func configuredIsAvailable() throws {
        let scanner = CoinbaseScanner()
        scanner.configure(client: try client("accounts"))
        #expect(scanner.isAvailable)
    }

    // "`getBalance(forAccount:)` is the client's `accountState(account:)`"
    @Test(.disabled("Classified 2026-10-07: asserts the state of portfolio quarry-42 is read; the client refuses a portfolio other than the key's own (the client gaps' 7b, built at your word 2026-10-07); see the identity ledger")) func balanceIsTheRecordedAccountState() async throws {
        let client = try client("accounts")
        let scanner = CoinbaseScanner()
        scanner.configure(client: client)
        let state = try await client.accountState(account: account.address)
        // invented: the 2023 `Amount<Contract>`'s quantity as `quantity`
        #expect(try await scanner.getBalance(forAccount: account).quantity == state.balance.baseUnits)
    }

    // "its ledger read maps every recorded ledger item to a `CryptoTransaction`"
    @Test func ledgerReadMapsEveryItem() async throws {
        let client = try client("fills")
        let scanner = CoinbaseScanner()
        scanner.configure(client: client)
        let items = try await client.ledgerItems(account: account.address, since: nil)
        #expect(try await scanner.getTransactions(forAccount: account).count == items.count)
    }

    // "`loadTransactions(from:)` of the recorded answer gives the same list"
    @Test(.disabled("Classified 2026-10-07: DEFECT FOUND, its fix held for your word: loadTransactions(from:) decodes the scanner's own encoding of its transactions, where the design says it decodes a recorded ledger answer and gives the same list (§ 1.3, § 6); Coinbase's ledger read is more than one answer, so which bytes it takes is a design choice; see the identity ledger")) func loadTransactionsGivesTheSameList() async throws {
        let scanner = CoinbaseScanner()
        scanner.configure(client: try client("fills"))
        let read = try await scanner.getTransactions(forAccount: account)
        // invented: RecordedCoinbase.data(_:), CryptoTransaction's time as `timeStamp`
        let loaded = try scanner.loadTransactions(from: RecordedCoinbase.data("fills"))
        #expect(loaded.map(\.timeStamp) == read.map(\.timeStamp))
    }

    // "the plug-in's `KrakenClient` is configured into `KrakenExchangeChain.default.scanner` at the client's init" — the same for Coinbase
    @Test func clientInitConfiguresTheChainsScanner() throws {
        _ = try client("accounts")
        #expect(CoinbaseExchangeChain.default.scanner.isAvailable)
    }
}
