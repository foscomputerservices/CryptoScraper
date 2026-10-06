// CoinbaseContractTests.swift — C31's contract run against CoinbaseClient.

import CryptoExchange
import CryptoCoinbase
import Testing

@Suite("C31 contract: CoinbaseClient")
struct CoinbaseContractTests {
    let contract = ExchangeClientContract(script: CoinbaseScript())

    @Test("C31 markets, T51, T52: lot sizes, minimums and leverage exactly") func markets() async throws { try await contract.checkMarkets() }
    @Test("C31 orderBook, T49, T50: mid, best bid and ask, volume exactly") func book() async throws { try await contract.checkBook() }
    @Test("C31 placeOrder: a fill is the typed result, the order sent exactly") func filled() async throws { try await contract.checkFilledOrder() }
    @Test("C31 placeOrder, T60: a partial fill at the units the exchange gave") func partlyFilled() async throws { try await contract.checkPartlyFilledOrder() }
    @Test("C31 placeOrder: an immediate-or-cancel order that met nothing") func unmatched() async throws { try await contract.checkUnmatchedOrder() }
    @Test("C31 placeOrder, T49: a refusal is a result with the exchange's words") func refused() async throws { try await contract.checkRefusedOrder() }
    @Test("T56: an unanswered order is never sent twice") func quietOrder() async throws { try await contract.checkQuietOrderIsNotRepeated() }
    @Test("C31 openOrders") func openOrders() async throws { try await contract.checkOpenOrders() }
    @Test("C31 cancelOrder: the request names the order") func cancel() async throws { try await contract.checkCancel() }
    @Test("C31 cancelOrder: a gone order is the exchange's typed error") func cancelGone() async throws { try await contract.checkCancelGone() }
    @Test("C31 accountState, T52: balance, positions, the mode") func accountState() async throws { try await contract.checkAccountState() }
    @Test("C31 ledgerItems, T54: fills with fees, funding, moves, oldest first") func ledger() async throws { try await contract.checkLedgerFirstRead() }
    @Test("T55: the ledger resumes after a cursor, never a timestamp alone") func ledgerResume() async throws { try await contract.checkLedgerResume() }
    @Test("T55: a cursor survives encoding") func ledgerCursor() async throws { try await contract.checkLedgerCursorSurvivesEncoding() }
    @Test("T54: a fill carries the order id placeOrder handed up") func fillOrderId() async throws { try await contract.checkFillCarriesTheOrderId() }
    @Test("C31 setLeverage: isolated, the leverage sent") func leverage() async throws { try await contract.checkLeverage() }
    @Test("C31 transfer, T103: between the account's own wallets, exactly") func transfer() async throws { try await contract.checkTransfer() }
    @Test("C31 keyFacts, T53, T103: the key's permissions") func keyFacts() async throws { try await contract.checkKeyFacts() }
    @Test("C31 errors: a rate limit carries Retry-After") func rateLimited() async throws { try await contract.checkRateLimited() }
    @Test("C31 errors: a malformed body is the typed error") func malformed() async throws { try await contract.checkMalformedBody() }
    @Test("C31: a separated number is refused, never rescued through a Double") func ambiguousNumber() async throws { try await contract.checkAmbiguousNumber() }
    @Test("C31 errors, T56: an unreachable exchange is the typed error") func unreachable() async throws { try await contract.checkUnreachable() }
    @Test("C31 errors, T103: a revoked key is the unauthorized error") func unauthorized() async throws { try await contract.checkUnauthorized() }
    @Test("T40: no key in a description, a debug description or a dump") func noKeyInDescriptions() throws { try contract.checkNoKeyInDescriptions() }
    @Test("T40: the secret never rides in a request") func noSecretInRequests() async throws { try await contract.checkNoSecretInRequests() }
    @Test("T40: no key in a log line") func noKeyInLogs() async throws { try await contract.checkNoKeyInLogs() }
    @Test("T40: no key in an error's description") func noKeyInErrors() async throws { try await contract.checkNoKeyInErrors() }
}
