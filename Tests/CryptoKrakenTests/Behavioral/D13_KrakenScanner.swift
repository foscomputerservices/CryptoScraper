// D13 — Kraken's exchange chain scanner, the adapter over C31's client.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.3: "`getBalance(forAccount:)` is the client's
// `accountState(account:)`, `getBalance(forToken:forAccount:)` that holding's balance in it, `getTransactions(forAccount:)`
// the client's `ledgerItems(account:since:)` mapped to a `CryptoTransaction` conformer per exchange, and
// `loadTransactions(from:)` decodes a recorded ledger answer. Each is made without credentials and keeps its client
// behind a `Mutex` with a `configure(client:)` door and an `isAvailable` ... unconfigured, it throws a typed error naming
// the exchange, never a zero." And § 6's "The exchange scanners" bullets.
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoExchange
import CryptoKraken
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D13 Kraken scanner")
struct D13_KrakenScannerTests {
    private let account = KrakenHolding(address: "bedrock")

    // invented: KrakenClient(credential:session:registry:), KrakenCredential.stub(), RecordedKraken.session(answering:) — as in D53
    private func client(_ recording: String) throws -> KrakenClient {
        try KrakenClient(credential: .stub(), session: RecordedKraken.session(answering: recording),
                         registry: AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    private func time<N, O, C>(of item: ExchangeClientLedgerItem<N, O, C>) -> Date {
        switch item {
        case let .fill(_, _, _, _, _, _, _, time, _, _): time
        case let .funding(_, _, _, time, _): time
        case let .deposit(_, time, _): time
        case let .withdrawal(_, time, _): time
        case let .internalMove(_, _, _, time, _): time
        }
    }

    // "Each is made without credentials" and "an `isAvailable`" — unconfigured, it is not available
    @Test func unconfiguredIsNotAvailable() {
        // invented: KrakenScanner() — "made without credentials" implies an empty initializer; none is declared
        #expect(!KrakenScanner().isAvailable)
    }

    // "unconfigured, it throws a typed error naming the exchange, never a zero"
    @Test(.disabled("Classified 2026-10-07: needs ExchangeScannerError.unconfigured(exchange:), not declared: the unconfigured scanner throws ExchangeClientError.unauthorized(text:) naming Kraken; see the identity ledger")) func unconfiguredBalanceThrowsNamingTheExchange() async {
        let scanner = KrakenScanner()
        // invented: ExchangeScannerError.unconfigured(exchange:) — "a typed error naming the exchange"; its type is not declared
        await #expect(throws: ExchangeScannerError.unconfigured(exchange: "Kraken")) {
            _ = try await scanner.getBalance(forAccount: account)
        }
    }

    // "unconfigured, it throws ... never a zero" — the transaction read too
    @Test(.disabled("Classified 2026-10-07: needs ExchangeScannerError.unconfigured(exchange:), not declared: the unconfigured scanner throws ExchangeClientError.unauthorized(text:) naming Kraken; see the identity ledger")) func unconfiguredTransactionsThrow() async {
        let scanner = KrakenScanner()
        await #expect(throws: ExchangeScannerError.unconfigured(exchange: "Kraken")) {
            _ = try await scanner.getTransactions(forAccount: account)
        }
    }

    // "a `configure(client:)` door" — configured, it is available
    @Test func configuredIsAvailable() throws {
        let scanner = KrakenScanner()
        scanner.configure(client: try client("Balance"))
        #expect(scanner.isAvailable)
    }

    // "Kraken's balance read is its recorded `accountState`"
    @Test func balanceIsTheRecordedAccountState() async throws {
        let client = try client("Balance")
        let scanner = KrakenScanner()
        scanner.configure(client: client)
        let state = try await client.accountState(account: account.address)
        let balance = try await scanner.getBalance(forAccount: account)
        // invented: the 2023 `Amount<Contract>`'s quantity as `quantity` — "The adapter converts at that one place" (§ 7.2); the member is not quoted
        #expect(balance.quantity == state.balance.baseUnits)
    }

    // "`getBalance(forToken:forAccount:)` that holding's balance in it"
    @Test func tokenBalanceIsThatHoldingsBalance() async throws {
        let scanner = KrakenScanner()
        scanner.configure(client: try client("Balance"))
        let xbt = try await scanner.getBalance(forToken: .xbt, forAccount: account)
        // invented: the 2023 Amount's contract as `contract` — as above
        #expect(xbt.contract == KrakenHolding.xbt)
    }

    // "its ledger read maps every recorded ledger item to a `CryptoTransaction` with the item's time, amount and id"
    @Test(.disabled("Classified 2026-10-07: the fill gained positionEffect at the owner's word; the pattern's arity is the projector's shape; see the identity ledger")) func ledgerReadMapsEveryItem() async throws {
        let client = try client("Ledgers")
        let scanner = KrakenScanner()
        scanner.configure(client: client)
        let items = try await client.ledgerItems(account: account.address, since: nil)
        let transactions = try await scanner.getTransactions(forAccount: account)
        #expect(transactions.count == items.count)
        // invented: CryptoTransaction's time as `timeStamp` — the 2023 protocol's member is not quoted
        #expect(transactions.map(\.timeStamp) == items.map(time(of:)))
    }

    // "`loadTransactions(from:)` of the recorded answer gives the same list"
    @Test(.disabled("Classified 2026-10-07: DEFECT FOUND, its fix held for your word: loadTransactions(from:) decodes the scanner's own encoding of its transactions, where the design says it decodes a recorded ledger answer and gives the same list (§ 1.3, § 6); Kraken's ledger read is two answers (TradesHistory and Ledgers), so which bytes it takes is a design choice; see the identity ledger")) func loadTransactionsGivesTheSameList() async throws {
        let scanner = KrakenScanner()
        scanner.configure(client: try client("Ledgers"))
        let read = try await scanner.getTransactions(forAccount: account)
        // invented: RecordedKraken.data(_:) — the recorded ledger answer as bytes
        let loaded = try scanner.loadTransactions(from: RecordedKraken.data("Ledgers"))
        #expect(loaded.map(\.timeStamp) == read.map(\.timeStamp))
        #expect(loaded.count == read.count)
    }

    // "so the plug-in's `KrakenClient` is configured into `KrakenExchangeChain.default.scanner` at the client's init"
    @Test func clientInitConfiguresTheChainsScanner() throws {
        _ = try client("Balance")
        #expect(KrakenExchangeChain.default.scanner.isAvailable)
    }
}
