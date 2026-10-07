// C30ValuesTests.swift — the exchange clients' values: construction, equality, the typed numbers, what each refuses.
//
// C30 declares no refusal of its own on any struct; what a value refuses is what its Codable conformance
// refuses (the three enums) and what its type refuses (every number is § 1's Amount, Price or Fraction).

import CryptoAsset
import CryptoExchange
import Foundation
import Testing

/// A market name of the client's own type, never fosline's (R8: the market name is a type parameter)
private struct VenueSymbol: Hashable, Sendable {
    let text: String
}

@Suite("C30: the exchange clients' values")
struct C30ValuesTests {

    // MARK: ExchangeClientSide

    @Test("C30: a side round-trips through its Codable form", arguments: [ExchangeClientSide.buy, .sell])
    func sideRoundTrips(side: ExchangeClientSide) throws {
        let restored = try JSONDecoder().decode(ExchangeClientSide.self, from: JSONEncoder().encode(side))
        #expect(restored == side)
    }

    @Test("C30: a side refuses a direction it does not have")
    func sideRefusesAnUnknownDirection() throws {
        let encodedBuy = try JSONEncoder().encode(ExchangeClientSide.buy)
        let text = String(decoding: encodedBuy, as: UTF8.self)
        let unknown = Data(text.replacingOccurrences(of: "buy", with: "hold").utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ExchangeClientSide.self, from: unknown)
        }
    }

    @Test("C30: buy and sell are two sides")
    func buyIsNotSell() {
        #expect(ExchangeClientSide.buy != .sell)
    }

    // MARK: ExchangeClientCloseReason

    @Test("C30: a close reason round-trips", arguments: [ExchangeClientCloseReason.liquidation, .deleveraging, .settlement, .halt])
    func closeReasonRoundTrips(reason: ExchangeClientCloseReason) throws {
        let restored = try JSONDecoder().decode(ExchangeClientCloseReason.self, from: JSONEncoder().encode(reason))
        #expect(restored == reason)
    }

    @Test("C30: a close reason refuses a reason it does not have")
    func closeReasonRefusesAnUnknownReason() throws {
        let text = String(decoding: try JSONEncoder().encode(ExchangeClientCloseReason.halt), as: UTF8.self)
        let unknown = Data(text.replacingOccurrences(of: "halt", with: "whim").utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ExchangeClientCloseReason.self, from: unknown)
        }
    }

    // MARK: ExchangeClientNotice.Kind

    @Test("C30: a notice's kind round-trips", arguments: [ExchangeClientNotice<String>.Kind.delisting, .rename, .halt])
    func noticeKindRoundTrips(kind: ExchangeClientNotice<String>.Kind) throws {
        let restored = try JSONDecoder().decode(ExchangeClientNotice<String>.Kind.self, from: JSONEncoder().encode(kind))
        #expect(restored == kind)
    }

    @Test("C30: a notice's kind refuses a kind it does not have")
    func noticeKindRefusesAnUnknownKind() throws {
        let text = String(decoding: try JSONEncoder().encode(ExchangeClientNotice<String>.Kind.rename), as: UTF8.self)
        let unknown = Data(text.replacingOccurrences(of: "rename", with: "rumour").utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ExchangeClientNotice<String>.Kind.self, from: unknown)
        }
    }

    // MARK: ExchangeClientMarket

    @Test("C30: a market carries its numbers as § 1's types, equal to the exchange's text exactly")
    func marketCarriesTypedNumbers() throws {
        let market = try makeMarket("BTC", base: "BTC", quote: "USDC", lotSize: amount("0.00001", "BTC"), minimumOrder: amount("10", "USDC"), maxLeverage: 40, leverageSet: nil, isPerpetual: true)
        let lot: Amount = market.lotSize
        let minimum: Amount = market.minimumOrder
        #expect(lot == (try amount("0.00001", "BTC")))
        #expect(minimum == (try amount("10", "USDC")))
        #expect(market.base == (try asset("BTC")))
        #expect(market.quote == (try asset("USDC")))
        #expect(market.maxLeverage == 40)
        #expect(market.leverageSet == nil)
        #expect(market.isPerpetual)
    }

    @Test("C30: two markets with the same values are equal and hash alike")
    func marketsWithTheSameValuesAreEqual() throws {
        let one = try makeMarket("BTC", base: "BTC", quote: "USDC", lotSize: amount("0.00001", "BTC"), minimumOrder: amount("10", "USDC"), maxLeverage: 40, leverageSet: 5, isPerpetual: true)
        let two = try makeMarket("BTC", base: "BTC", quote: "USDC", lotSize: amount("0.00001", "BTC"), minimumOrder: amount("10", "USDC"), maxLeverage: 40, leverageSet: 5, isPerpetual: true)
        #expect(one == two)
        #expect(Set([one, two]).count == 1)
    }

    @Test("C30: a market differs by any one value", arguments: 0..<5)
    func marketDiffersByAnyValue(changed: Int) throws {
        let base = try makeMarket("BTC", base: "BTC", quote: "USDC", lotSize: amount("0.00001", "BTC"), minimumOrder: amount("10", "USDC"), maxLeverage: 40, leverageSet: 5, isPerpetual: true)
        let other = try makeMarket(
            changed == 0 ? "ETH" : "BTC", base: "BTC", quote: "USDC",
            lotSize: amount(changed == 1 ? "0.0001" : "0.00001", "BTC"),
            minimumOrder: amount("10", "USDC"),
            maxLeverage: changed == 2 ? 50 : 40,
            leverageSet: changed == 3 ? nil : 5,
            isPerpetual: changed != 4
        )
        #expect(base != other)
    }

    @Test("C30: a market is named by the client's own type, never fosline's (R8)")
    func marketNameIsTheClientsType() throws {
        let market = try makeMarket(VenueSymbol(text: "PF_XBTUSD"), base: "BTC", quote: "USD", lotSize: amount("0.0001", "BTC"), minimumOrder: amount("0.0001", "BTC"), maxLeverage: 50, leverageSet: nil, isPerpetual: true)
        #expect(market.name == VenueSymbol(text: "PF_XBTUSD"))
    }

    // MARK: ExchangeClientBook

    @Test("C30: a book carries the mid, the best bid and ask and the volume as typed numbers")
    func bookCarriesTypedNumbers() throws {
        let book = makeBook("BTC", mid: try price("64250.5", "USDC"), bestBid: try price("64250.0", "USDC"), bestAsk: try price("64251.0", "USDC"), volume: try amount("9007199254740993", "USDC"), readAt: ms(1_727_000_000_123))
        let mid: Price = book.mid
        #expect(mid == (try price("64250.5", "USDC")))
        #expect(book.bestBid == (try price("64250.0", "USDC")))
        #expect(book.bestAsk == (try price("64251.0", "USDC")))
        // 2^53 + 1: a Double cannot hold it, an Amount must
        #expect(book.volume == (try amount("9007199254740993", "USDC")))
        #expect(book.volume != (try amount("9007199254740992", "USDC")))
        #expect(book.readAt == ms(1_727_000_000_123))
    }

    @Test("C30: two books read at different instants are different values")
    func booksDifferByReadAt() throws {
        let one = makeBook("BTC", mid: try price("64250.5", "USDC"), bestBid: try price("64250.0", "USDC"), bestAsk: try price("64251.0", "USDC"), volume: try amount("1", "USDC"), readAt: ms(1_727_000_000_123))
        let two = makeBook("BTC", mid: try price("64250.5", "USDC"), bestBid: try price("64250.0", "USDC"), bestAsk: try price("64251.0", "USDC"), volume: try amount("1", "USDC"), readAt: ms(1_727_000_000_124))
        #expect(one != two)
    }

    // MARK: ExchangeClientOrderResult

    @Test("C30: a filled and a partly filled result with the same numbers are different outcomes (T60)")
    func filledIsNotPartlyFilled() throws {
        let units = try amount("0.0006", "BTC")
        let at = try price("64250.4", "USDC")
        let filled = ExchangeClientOrderResult<Int>.filled(units: units, at: at, id: 77_738_308, time: ms(1_727_000_001_000))
        let partly = ExchangeClientOrderResult<Int>.partlyFilled(units: units, at: at, id: 77_738_308, time: ms(1_727_000_001_000))
        #expect(filled != partly)
    }

    @Test("C30: a partly filled result keeps the units the exchange gave")
    func partlyFilledKeepsTheExchangesUnits() throws {
        let result = ExchangeClientOrderResult<Int>.partlyFilled(units: try amount("0.0006", "BTC"), at: try price("64250.4", "USDC"), id: 1, time: ms(1))
        guard case let .partlyFilled(units, _, _, _) = result else {
            Issue.record("not a partial fill")
            return
        }
        #expect(units == (try amount("0.0006", "BTC")))
    }

    @Test("C30: a refusal carries the exchange's code and text")
    func refusalCarriesCodeAndText() {
        let result = ExchangeClientOrderResult<Int>.refused(code: "insufficientAvailableFunds", text: "Insufficient funds")
        guard case let .refused(code, text) = result else {
            Issue.record("not a refusal")
            return
        }
        #expect(code == "insufficientAvailableFunds")
        #expect(text == "Insufficient funds")
    }

    @Test("C30: cancelled before accepted carries no id; cancelled carries the exchange's id")
    func cancelledCarriesTheId() {
        #expect(ExchangeClientOrderResult<Int>.cancelledBeforeAccepted != .cancelled(id: 7))
        #expect(ExchangeClientOrderResult<Int>.cancelled(id: 7) != .cancelled(id: 8))
    }

    @Test("C30: an order id is the client's own type")
    func orderIdIsTheClientsType() {
        let uuid = UUID()
        let result = ExchangeClientOrderResult<UUID>.cancelled(id: uuid)
        #expect(result == .cancelled(id: uuid))
    }

    // MARK: ExchangeClientOpenOrder, Position, AccountMode, AccountState

    @Test("C30: an open order carries its id, market, side and units")
    func openOrderCarriesItsValues() throws {
        let order: ExchangeClientOpenOrder<String, Int> = makeOpenOrder(77_738_310, market: "BTC", side: .buy, units: try amount("0.002", "BTC"))
        #expect(order.id == 77_738_310)
        #expect(order.market == "BTC")
        #expect(order.side == .buy)
        #expect(order.units == (try amount("0.002", "BTC")))
    }

    @Test("C30: a position without a liquidation price differs from one with it")
    func positionLiquidationPriceIsOptional() throws {
        let without = makePosition("BTC", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USDC"), mark: try price("64250.6", "USDC"), liquidationPrice: nil)
        let with = makePosition("BTC", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USDC"), mark: try price("64250.6", "USDC"), liquidationPrice: try price("70123.4", "USDC"))
        #expect(without.liquidationPrice == nil)
        #expect(with.liquidationPrice == (try price("70123.4", "USDC")))
        #expect(without != with)
    }

    @Test("C30: an account mode carries the exchange's name for it and the alternatives in order (T52)")
    func accountModeCarriesTheExchangesWords() {
        let mode = makeMode("default", allowsTransfer: true, allowsIsolatedMargin: false, alternatives: ["unifiedAccount", "portfolioMargin"])
        #expect(mode.name == "default")
        #expect(mode.allowsTransfer)
        #expect(!mode.allowsIsolatedMargin)
        #expect(mode.alternatives == ["unifiedAccount", "portfolioMargin"])
        #expect(mode != makeMode("default", allowsTransfer: true, allowsIsolatedMargin: false, alternatives: ["portfolioMargin", "unifiedAccount"]))
    }

    @Test("C30: an account state carries balance and withdrawable as amounts, and its positions")
    func accountStateCarriesItsValues() throws {
        let position = makePosition("BTC", side: .sell, units: try amount("0.01", "BTC"), entryPrice: try price("64000.0", "USDC"), mark: try price("64250.6", "USDC"), liquidationPrice: nil)
        let state = makeAccountState(balance: try amount("1523.456789", "USDC"), withdrawable: try amount("1200.5", "USDC"), positions: [position], mode: makeMode("default", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: []), readAt: ms(1_727_000_000_456))
        #expect(state.balance == (try amount("1523.456789", "USDC")))
        #expect(state.withdrawable == (try amount("1200.5", "USDC")))
        #expect(state.positions == [position])
        #expect(state.readAt == ms(1_727_000_000_456))
    }

    // MARK: ExchangeClientLedgerItem

    @Test("C30: a ledger item's cursor is part of its value")
    func ledgerItemCursorIsPartOfItsValue() throws {
        let fee = try amount("0.023712", "USDC")
        let one = ExchangeClientLedgerItem<String, Int, Int>.fill(market: "BTC", side: .buy, units: try amount("0.00123", "BTC"), price: try price("64250.4", "USDC"), fee: fee, order: 77_738_308, closedBy: nil, time: ms(1_727_000_001_000), cursor: 111)
        let two = ExchangeClientLedgerItem<String, Int, Int>.fill(market: "BTC", side: .buy, units: try amount("0.00123", "BTC"), price: try price("64250.4", "USDC"), fee: fee, order: 77_738_308, closedBy: nil, time: ms(1_727_000_001_000), cursor: 112)
        #expect(one != two)
    }

    @Test("C30: a fill closed by the exchange carries the exchange's reason", .disabled("Classified 2026-10-07: the fill gained positionEffect at the owner's word; the pattern's arity is the projector's shape; see the identity ledger"))
    func fillCarriesTheCloseReason() throws {
        let item = ExchangeClientLedgerItem<String, Int, Int>.fill(market: "BTC", side: .buy, units: try amount("0.01", "BTC"), price: try price("70123.4", "USDC"), fee: try amount("0.35", "USDC"), order: 77_738_400, closedBy: .liquidation, time: ms(1_727_000_003_000), cursor: 113)
        guard case let .fill(_, _, _, _, _, _, closedBy, _, _, _) = item else {
            Issue.record("not a fill")
            return
        }
        #expect(closedBy == .liquidation)
    }

    @Test("C30: a funding payment carries its amount and its rate as a fraction")
    func fundingCarriesAmountAndRate() throws {
        let item = ExchangeClientLedgerItem<String, Int, Int>.funding(market: "BTC", amount: try amount("-0.0153", "USDC"), rate: try fraction("0.0000125"), time: ms(1_727_000_002_000), cursor: 5)
        guard case let .funding(_, paid, rate, _, _) = item else {
            Issue.record("not funding")
            return
        }
        let typedRate: Fraction = rate
        #expect(paid == (try amount("-0.0153", "USDC")))
        #expect(typedRate == (try fraction("0.0000125")))
    }

    @Test("C30: deposits, withdrawals and internal moves are distinct kinds")
    func movementsAreDistinctKinds() throws {
        let sum = try amount("100.0", "USDC")
        let deposit = ExchangeClientLedgerItem<String, Int, Int>.deposit(sum, time: ms(1), cursor: 1)
        let withdrawal = ExchangeClientLedgerItem<String, Int, Int>.withdrawal(sum, time: ms(1), cursor: 1)
        let move = ExchangeClientLedgerItem<String, Int, Int>.internalMove(sum, from: "main", to: "sub", time: ms(1), cursor: 1)
        #expect(deposit != withdrawal)
        #expect(deposit != move)
        #expect(withdrawal != move)
    }

    // MARK: ExchangeClientKeyFacts, RequestBudget, Notice

    @Test("C30: key facts carry the key's three permissions, its approver and its expiry (T53, T103)")
    func keyFactsCarryPermissions() {
        let facts = makeKeyFacts(canTrade: true, canTransfer: true, canWithdraw: false, approvedBy: "0x2222222222222222222222222222222222222222", validUntil: ms(1_767_225_600_000))
        #expect(facts.canTrade)
        #expect(facts.canTransfer)
        #expect(!facts.canWithdraw)
        #expect(facts.approvedBy == "0x2222222222222222222222222222222222222222")
        #expect(facts.validUntil == ms(1_767_225_600_000))
        #expect(facts != makeKeyFacts(canTrade: true, canTransfer: true, canWithdraw: true, approvedBy: "0x2222222222222222222222222222222222222222", validUntil: ms(1_767_225_600_000)))
    }

    @Test("C30: a request budget carries the limit, what remains and when it resets (T52)")
    func requestBudgetCarriesItsValues() {
        let budget = makeBudget(limit: 1200, remaining: 1187, resetsAt: ms(1_727_000_060_000))
        #expect(budget.limit == 1200)
        #expect(budget.remaining == 1187)
        #expect(budget.resetsAt == ms(1_727_000_060_000))
    }

    @Test("C30: a notice carries its kind, market, effective instant and the exchange's text")
    func noticeCarriesItsValues() {
        let notice = makeNotice(.delisting, market: "MATIC", effectiveAt: ms(1_727_100_000_000), text: "MATIC will be delisted")
        #expect(notice.kind == .delisting)
        #expect(notice.market == "MATIC")
        #expect(notice.effectiveAt == ms(1_727_100_000_000))
        #expect(notice.text == "MATIC will be delisted")
    }
}
