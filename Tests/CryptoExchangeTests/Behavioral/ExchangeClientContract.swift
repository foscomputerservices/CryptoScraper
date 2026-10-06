// ExchangeClientContract.swift — C31's contract, written once, generic over any conformer.
//
// Each plug-in's test target supplies an `ExchangeClientScript` (its exchange's wire bodies and the values
// its client must hand up for them) and runs every check below from its own @Test functions.
//
// The typed errors: C31 says "its typed errors" and AR31 says an error response decodes "into a Swift Error",
// but no error type is declared. The smallest one that carries what the brief and T56/T103 demand is invented
// here as `ExchangeClientError` and every line that names it is marked.

import CryptoAsset
import CryptoExchange
import Foundation
import Testing

// MARK: - The cases a script supplies

/// Routes to answer with, the value the client must hand up, and texts its requests must carry
struct ScriptedCase<Value> {
    let routes: [ScriptedRoute]
    let expected: Value
    var sent: [String] = []
}

/// One placeOrder call and the outcome the exchange's answer must become
struct OrderCase<Client: ExchangeClient> {
    let side: ExchangeClientSide
    let size: Amount
    let limit: Price
    var immediateOrCancel = true
    var reduceOnly = false
    let routes: [ScriptedRoute]
    let expected: OrderOutcome<Client.OrderId>
    /// The exchange's own code for a refusal, when it sends one; nil leaves the code unasserted
    var expectedRefusalCode: String? = nil
    /// The size and the limit as exact decimal text, the side, the time in force, the account
    var sent: [String] = []
}

/// The ledger read twice: from the start, then resumed after one item's cursor (T54, T55)
struct LedgerCase<Client: ExchangeClient> {
    let firstRoutes: [ScriptedRoute]
    /// Oldest first
    let firstExpected: [LedgerLine<Client.MarketName, Client.OrderId>]
    /// The index in `firstExpected` whose cursor the resumed read starts after
    let resumeAfter: Int
    /// The exchange's answer to the resumed read: it may repeat items at or before the cursor's instant
    let resumeRoutes: [ScriptedRoute]
    /// Only what lies after the cursor, including an unseen item at the cursor's own instant
    let resumeExpected: [LedgerLine<Client.MarketName, Client.OrderId>]
    var resumeSent: [String] = []
}

/// A scripted error and the typed error it must become
struct ErrorCase {
    let routes: [ScriptedRoute]
    let expected: ExchangeClientError // INVENTED: ExchangeClientError, C31's undeclared typed errors
}

/// One exchange's wire, scripted, with the values its client must hand up
protocol ExchangeClientScript: Sendable {
    associatedtype Client: ExchangeClient

    /// A fresh client over the scripted session, with the test credential, logging into `log`
    func makeClient(session: ScriptedSession, log: LogCapture) throws -> Client

    /// Every text of the credential that may never leave the client: the secret, the private key (T40)
    var secretTexts: [String] { get }
    /// The key's public half (an API key): it may ride in a request header, never in a description, a log line or an error (T40)
    var keyIdentifierTexts: [String] { get }

    var market: Client.MarketName { get }
    /// The exchange's own name for the account the orders are placed in
    var account: String { get }

    func marketsCase() throws -> ScriptedCase<[ExchangeClientMarket<Client.MarketName>]>
    /// `readAt` is not compared
    func bookCase() throws -> ScriptedCase<ExchangeClientBook<Client.MarketName>>
    func filledOrder() throws -> OrderCase<Client>
    func partlyFilledOrder() throws -> OrderCase<Client>
    func unmatchedOrder() throws -> OrderCase<Client>
    func refusedOrder() throws -> OrderCase<Client>
    /// Routes under which the order request itself goes unanswered; the rest answer
    func quietOrderRoutes() throws -> (routes: [ScriptedRoute], orderNeedle: String)
    func openOrdersCase() throws -> ScriptedCase<[ExchangeClientOpenOrder<Client.MarketName, Client.OrderId>]>
    /// The id to cancel; `expected` is unused
    func cancelCase() throws -> (id: Client.OrderId, scripted: ScriptedCase<Void>)
    /// Cancelling an order the exchange no longer has
    func cancelGoneCase() throws -> (id: Client.OrderId, error: ErrorCase)
    /// `readAt` is not compared
    func accountStateCase() throws -> ScriptedCase<ExchangeClientAccountState<Client.MarketName>>
    func ledgerCase() throws -> LedgerCase<Client>
    func leverageCase() throws -> (leverage: Int, scripted: ScriptedCase<Void>)
    /// A transfer between the account's own wallets (T103)
    func transferCase() throws -> (amount: Amount, from: String, to: String, scripted: ScriptedCase<Void>)
    func keyFactsCase() throws -> ScriptedCase<ExchangeClientKeyFacts>

    /// Every request answered 429 with Retry-After: 7
    func rateLimitedCase() throws -> ErrorCase
    /// The book's answer carries a number that is not a number
    func malformedBookCase() throws -> ErrorCase
    /// The book's answer carries a number with a thousands separator, which no Double parse may rescue
    func ambiguousNumberBookCase() throws -> ErrorCase
    /// The exchange refuses the key on an order (a revoked key, T103)
    func unauthorizedOrderCase() throws -> ErrorCase
}

extension ExchangeClientScript {
    func quietRoutes() -> [ScriptedRoute] { [.unreachable("")] }
}

// MARK: - The contract

struct ExchangeClientContract<Script: ExchangeClientScript> {
    let script: Script

    private func client(_ routes: [ScriptedRoute]) throws -> (Script.Client, ScriptedSession, LogCapture) {
        let session = ScriptedSession(routes)
        let log = LogCapture()
        return (try script.makeClient(session: session, log: log), session, log)
    }

    // MARK: C31 members

    /// C31 markets, T51, T52: names, lot sizes, minimums and leverage as the exchange gives them, exactly
    func checkMarkets() async throws {
        let scripted = try script.marketsCase()
        let (client, session, _) = try client(scripted.routes)
        let markets = try await client.markets()
        #expect(markets == scripted.expected)
        expectSent(scripted.sent, in: session)
    }

    /// C31 orderBook, T49, T50: the mid, the best bid and ask, the volume, exactly
    func checkBook() async throws {
        let scripted = try script.bookCase()
        let (client, session, _) = try client(scripted.routes)
        let book = try await client.orderBook(market: script.market)
        #expect(book.market == scripted.expected.market)
        #expect(book.mid == scripted.expected.mid)
        #expect(book.bestBid == scripted.expected.bestBid)
        #expect(book.bestAsk == scripted.expected.bestAsk)
        #expect(book.volume == scripted.expected.volume)
        expectSent(scripted.sent, in: session)
    }

    /// C31 placeOrder: the exchange's answer becomes the typed result, and the request carries the order exactly
    func checkOrder(_ order: OrderCase<Script.Client>) async throws {
        let (client, session, _) = try client(order.routes)
        let result = try await client.placeOrder(
            market: script.market, side: order.side, size: order.size, limit: order.limit,
            immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
        )
        #expect(outcome(result) == order.expected)
        if let code = order.expectedRefusalCode {
            #expect(refusalCode(result) == code)
        }
        expectSent(order.sent, in: session)
    }

    func checkFilledOrder() async throws { try await checkOrder(script.filledOrder()) }

    /// T60: a partial fill is its own outcome, at the units the exchange gave
    func checkPartlyFilledOrder() async throws { try await checkOrder(script.partlyFilledOrder()) }

    /// An immediate-or-cancel order that met nothing
    func checkUnmatchedOrder() async throws { try await checkOrder(script.unmatchedOrder()) }

    /// T49: a refused order is a result carrying the exchange's own words, never a thrown error
    func checkRefusedOrder() async throws { try await checkOrder(script.refusedOrder()) }

    /// T56: an order that went unanswered is never sent again by the client
    func checkQuietOrderIsNotRepeated() async throws {
        let quiet = try script.quietOrderRoutes()
        let order = try script.filledOrder()
        let (client, session, _) = try client(quiet.routes)
        await #expect(throws: ExchangeClientError.unreachable) { // INVENTED: ExchangeClientError.unreachable
            _ = try await client.placeOrder(
                market: script.market, side: order.side, size: order.size, limit: order.limit,
                immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
            )
        }
        #expect(session.count(matching: quiet.orderNeedle) == 1)
    }

    /// C31 openOrders
    func checkOpenOrders() async throws {
        let scripted = try script.openOrdersCase()
        let (client, session, _) = try client(scripted.routes)
        let orders = try await client.openOrders(account: script.account)
        #expect(orders == scripted.expected)
        expectSent(scripted.sent, in: session)
    }

    /// C31 cancelOrder: the request names the order
    func checkCancel() async throws {
        let cancel = try script.cancelCase()
        let (client, session, _) = try client(cancel.scripted.routes)
        try await client.cancelOrder(cancel.id, market: script.market, account: script.account)
        expectSent(cancel.scripted.sent, in: session)
    }

    /// C31 cancelOrder: an order the exchange no longer has is the exchange's typed error, its words kept
    func checkCancelGone() async throws {
        let gone = try script.cancelGoneCase()
        let (client, _, _) = try client(gone.error.routes)
        await #expect(throws: gone.error.expected) {
            try await client.cancelOrder(gone.id, market: script.market, account: script.account)
        }
    }

    /// C31 accountState, T52: balance, withdrawable, positions and the account's mode, exactly
    func checkAccountState() async throws {
        let scripted = try script.accountStateCase()
        let (client, session, _) = try client(scripted.routes)
        let state = try await client.accountState(account: script.account)
        #expect(state.balance == scripted.expected.balance)
        #expect(state.withdrawable == scripted.expected.withdrawable)
        #expect(state.positions == scripted.expected.positions)
        #expect(state.mode == scripted.expected.mode)
        expectSent(scripted.sent, in: session)
    }

    /// C31 ledgerItems, T54: fills with their fees and order ids, funding, deposits, withdrawals, moves, oldest first
    func checkLedgerFirstRead() async throws {
        let ledger = try script.ledgerCase()
        let (client, _, _) = try client(ledger.firstRoutes)
        let items = try await client.ledgerItems(account: script.account, since: nil)
        #expect(items.map { line($0) } == ledger.firstExpected)
        // every item carries the cursor after it: no two items share one
        #expect(Set(items.map { cursor($0) }).count == items.count)
    }

    /// T55: resumed after an item's cursor, never from its timestamp alone
    func checkLedgerResume() async throws {
        let ledger = try script.ledgerCase()
        let (first, _, _) = try client(ledger.firstRoutes)
        let items = try await first.ledgerItems(account: script.account, since: nil)
        try #require(items.indices.contains(ledger.resumeAfter))
        let after = cursor(items[ledger.resumeAfter])

        let (resumed, session, _) = try client(ledger.resumeRoutes)
        let later = try await resumed.ledgerItems(account: script.account, since: after)
        let lines = later.map { line($0) }
        // nothing at or before the cursor comes back; an unseen item at the cursor's own instant does
        #expect(Set(lines) == Set(ledger.resumeExpected))
        #expect(lines.count == ledger.resumeExpected.count)
        // oldest first
        #expect(lines.map(\.time) == lines.map(\.time).sorted())
        expectSent(ledger.resumeSent, in: session)
    }

    /// T55: a cursor survives a restart: encoded and decoded, it resumes the same read
    func checkLedgerCursorSurvivesEncoding() async throws {
        let ledger = try script.ledgerCase()
        let (client, _, _) = try client(ledger.firstRoutes)
        let items = try await client.ledgerItems(account: script.account, since: nil)
        for item in items {
            let kept = cursor(item)
            let restored = try JSONDecoder().decode(Script.Client.Cursor.self, from: JSONEncoder().encode(kept))
            #expect(restored == kept)
        }
    }

    /// T54: a fill is matched to its order by the exchange's own order id, the same one placeOrder handed up
    func checkFillCarriesTheOrderId() async throws {
        let order = try script.filledOrder()
        guard case let .filled(_, _, placedId) = order.expected else {
            Issue.record("the script's filled order must expect .filled")
            return
        }
        let ledger = try script.ledgerCase()
        let fillOrders = ledger.firstExpected.compactMap { line -> Script.Client.OrderId? in
            if case let .fill(_, _, _, _, _, order, _, _) = line { return order }
            return nil
        }
        #expect(fillOrders.contains(placedId))
    }

    /// C31 setLeverage: the request carries the leverage and isolated margin (C31's note: fosline passes isolated)
    func checkLeverage() async throws {
        let leverage = try script.leverageCase()
        let (client, session, _) = try client(leverage.scripted.routes)
        try await client.setLeverage(leverage.leverage, market: script.market, isolated: true, account: script.account)
        expectSent(leverage.scripted.sent, in: session)
    }

    /// C31 transfer, T103: a move between the account's own wallets carries the amount exactly
    func checkTransfer() async throws {
        let transfer = try script.transferCase()
        let (client, session, _) = try client(transfer.scripted.routes)
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        expectSent(transfer.scripted.sent, in: session)
    }

    /// C31 keyFacts, T53, T103: what the key may do, who approved it and until when, as the exchange says
    func checkKeyFacts() async throws {
        let scripted = try script.keyFactsCase()
        let (client, session, _) = try client(scripted.routes)
        let facts = try await client.keyFacts()
        #expect(facts == scripted.expected)
        expectSent(scripted.sent, in: session)
    }

    // MARK: Typed errors, each from a scripted response

    /// A rate limit is the typed limit error carrying the exchange's Retry-After
    func checkRateLimited() async throws {
        let scripted = try script.rateLimitedCase()
        let (client, _, _) = try client(scripted.routes)
        await #expect(throws: scripted.expected) {
            _ = try await client.orderBook(market: script.market)
        }
    }

    /// A malformed body is the typed error, never a value
    func checkMalformedBody() async throws {
        let scripted = try script.malformedBookCase()
        let (client, _, _) = try client(scripted.routes)
        await #expect(throws: scripted.expected) {
            _ = try await client.orderBook(market: script.market)
        }
    }

    /// A number in a form no exact parse admits is refused, never rescued through a Double
    func checkAmbiguousNumber() async throws {
        let scripted = try script.ambiguousNumberBookCase()
        let (client, _, _) = try client(scripted.routes)
        await #expect(throws: scripted.expected) {
            _ = try await client.orderBook(market: script.market)
        }
    }

    /// T56: an exchange that does not answer is the typed error, so the caller can hold a health state
    func checkUnreachable() async throws {
        let (client, _, _) = try client(script.quietRoutes())
        await #expect(throws: ExchangeClientError.unreachable) { // INVENTED: ExchangeClientError.unreachable
            _ = try await client.orderBook(market: script.market)
        }
    }

    /// T103: a revoked key is the typed error, so the stream can halt with the reason shown
    func checkUnauthorized() async throws {
        let scripted = try script.unauthorizedOrderCase()
        let order = try script.filledOrder()
        let (client, _, _) = try client(scripted.routes)
        await #expect(throws: scripted.expected) {
            _ = try await client.placeOrder(
                market: script.market, side: order.side, size: order.size, limit: order.limit,
                immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
            )
        }
    }

    // MARK: T40: no key leaves the client

    /// A description, a debug description and a dump of the client never show a key
    func checkNoKeyInDescriptions() throws {
        let (client, _, _) = try client([])
        var dumped = ""
        dump(client, to: &dumped)
        let secrets = script.secretTexts + script.keyIdentifierTexts
        expectNoSecret(secrets, in: String(describing: client), "the description")
        expectNoSecret(secrets, in: String(reflecting: client), "the debug description")
        expectNoSecret(secrets, in: dumped, "a dump")
    }

    /// The secret never rides in a request: only what is computed from it does
    func checkNoSecretInRequests() async throws {
        let order = try script.filledOrder()
        let transfer = try script.transferCase()
        let (client, session, _) = try client(order.routes + transfer.scripted.routes)
        _ = try await client.placeOrder(
            market: script.market, side: order.side, size: order.size, limit: order.limit,
            immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
        )
        try await client.transfer(transfer.amount, from: transfer.from, to: transfer.to)
        #expect(!session.requests.isEmpty)
        expectNoSecret(script.secretTexts, in: session.everythingSent, "a request")
    }

    /// No log line carries a key, on the happy path or an error's
    func checkNoKeyInLogs() async throws {
        let order = try script.filledOrder()
        let refused = try script.unauthorizedOrderCase()
        let secrets = script.secretTexts + script.keyIdentifierTexts
        for routes in [order.routes, refused.routes, script.quietRoutes()] {
            let (client, _, log) = try client(routes)
            do {
                _ = try await client.placeOrder(
                    market: script.market, side: order.side, size: order.size, limit: order.limit,
                    immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
                )
            } catch {
                // the errors are the other checks' business; here only the log lines are read
            }
            for logged in log.lines {
                expectNoSecret(secrets, in: logged, "a log line")
            }
        }
    }

    /// A thrown error's description never carries a key
    func checkNoKeyInErrors() async throws {
        let order = try script.filledOrder()
        let secrets = script.secretTexts + script.keyIdentifierTexts
        let unauthorized = try script.unauthorizedOrderCase().routes
        let limited = try script.rateLimitedCase().routes
        for routes in [unauthorized, script.quietRoutes(), limited] {
            let (client, _, _) = try client(routes)
            do {
                _ = try await client.placeOrder(
                    market: script.market, side: order.side, size: order.size, limit: order.limit,
                    immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: script.account
                )
                Issue.record("the scripted error was not thrown")
            } catch {
                expectNoSecret(secrets, in: String(describing: error), "an error's description")
                expectNoSecret(secrets, in: String(reflecting: error), "an error's debug description")
            }
        }
    }
}
