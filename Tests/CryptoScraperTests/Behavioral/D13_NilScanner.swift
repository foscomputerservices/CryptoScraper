// D13 — The NilScanner, and the scanner never nil.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.3: "`NilScanner`, in your `ZeroAmountScanner`'s
// pattern: zero balances and no transactions ..., generic over the contract since yours is bound to
// `ZeroAmountContract`." and "public var userReadableName: String { get }   // \"No scanner\"". And § 6:
// "`NilScanner<BinanceHolding>` answers zero for both balances and an empty list for both transaction reads, as
// `ZeroAmountScanner` does." and "a test reads `EthereumChain.default.scanner.userReadableName` with no unwrap." And the
// owner's ruling of 2026-10-07: a scanner is never nil.
// Binance's own `NilScanner<BinanceHolding>` is read in CryptoOHLCVTests' D13; here the scanner is generic over a chain contract.

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D13 NilScanner")
struct D13_NilScannerTests {
    private let account = EthereumContract(address: "0x0000000000000000000000000000000000000042")
    private let token = EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")

    // "public var userReadableName: String { get }   // \"No scanner\""
    @Test func readableNameIsNoScanner() {
        #expect(NilScanner<EthereumContract>().userReadableName == "No scanner")
    }

    // "answers zero for both balances" — the account's balance
    @Test func accountBalanceIsZero() async throws {
        let balance = try await NilScanner<EthereumContract>().getBalance(forAccount: account)
        // invented: the 2023 `Amount<Contract>`'s quantity as `quantity` — the member is not quoted
        #expect(balance.quantity == 0)
    }

    // "answers zero for both balances" — a token's balance in the account
    @Test func tokenBalanceIsZero() async throws {
        let balance = try await NilScanner<EthereumContract>().getBalance(forToken: token, forAccount: account)
        #expect(balance.quantity == 0)
    }

    // "an empty list for both transaction reads" — the account's transactions
    @Test func transactionsAreEmpty() async throws {
        #expect(try await NilScanner<EthereumContract>().getTransactions(forAccount: account).isEmpty)
    }

    // "an empty list for both transaction reads" — loading recorded transactions
    @Test func loadedTransactionsAreEmpty() throws {
        #expect(try NilScanner<EthereumContract>().loadTransactions(from: Data("[]".utf8)).isEmpty)
    }

    // "The road not taken: a scanner that throws instead of answering zero." — it answers, it does not throw
    @Test func answersAndDoesNotThrow() async {
        await #expect(throws: Never.self) {
            _ = try await NilScanner<EthereumContract>().getBalance(forAccount: account)
        }
    }

    // "Your protocol's `scanner` becomes non-optional: `var scanner: Scanner { get }`"
    @Test func ethereumsScannerIsReadWithNoUnwrap() {
        let name: String = EthereumChain.default.scanner.userReadableName
        #expect(!name.isEmpty)
    }

    // "Your seven chains already assign one ... so they only drop the `?`" — Bitcoin's and Tron's too
    @Test func otherChainsScannersAreNonOptional() {
        let bitcoin: String = BitcoinChain.default.scanner.userReadableName
        let tron: String = TronChain.default.scanner.userReadableName
        #expect(!bitcoin.isEmpty)
        #expect(!tron.isEmpty)
    }
}
