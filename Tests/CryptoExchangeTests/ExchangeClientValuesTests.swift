// ExchangeClientValuesTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import FOSFoundation
import Foundation
import Testing

// C30's values: made by their initializers, compared by value, their numbers § 1's types.

@Suite("C30: the exchange clients' values")
struct ExchangeClientValuesTests {
    static let btc = try! Asset(symbol: "BTC", unitExponent: 5)
    static let usdc = Asset.usdc
    static let mid = Price(Amount(whole: 65_000, of: usdc), per: btc)

    @Test func theSideRoundTripsThroughJSONByItsCaseName() throws {
        for side in [ExchangeClientSide.buy, .sell] {
            #expect(try side.toJSON().fromJSON() == side)
        }
        #expect(ExchangeClientSide.stub() == .buy)
    }

    @Test func theCloseReasonAndTheNoticeKindRoundTrip() throws {
        for reason in [ExchangeClientCloseReason.liquidation, .deleveraging, .settlement, .halt] {
            #expect(try reason.toJSON().fromJSON() == reason)
        }
        for kind in [ExchangeClientNotice<String>.Kind.delisting, .rename, .halt] {
            #expect(try kind.toJSON().fromJSON() == kind)
        }
    }

    @Test func aMarketIsComparedByEveryValue() {
        let market = ExchangeClientMarket(name: "BTC", base: Self.btc, quote: Self.usdc,
                                          lotSize: Amount(baseUnits: 1, asset: Self.btc),
                                          minimumOrder: Amount(baseUnits: 10, asset: Self.btc),
                                          maxLeverage: 40, leverageSet: nil, isPerpetual: true)
        let other = ExchangeClientMarket(name: "BTC", base: Self.btc, quote: Self.usdc,
                                         lotSize: Amount(baseUnits: 1, asset: Self.btc),
                                         minimumOrder: Amount(baseUnits: 10, asset: Self.btc),
                                         maxLeverage: 40, leverageSet: 2, isPerpetual: true)
        #expect(market != other)
        #expect(market.lotSize.baseUnits == 1)
    }

    @Test func aBooksNumbersAreExact() {
        let bid = Price(Amount(baseUnits: 64_999_000_000, asset: Self.usdc), per: Self.btc)
        let ask = Price(Amount(baseUnits: 65_001_000_000, asset: Self.usdc), per: Self.btc)
        let book = ExchangeClientBook(market: "BTC", mid: Self.mid, bestBid: bid, bestAsk: ask,
                                      baseVolume: Amount(whole: 1_234, of: Self.btc), quoteVolume: Amount(whole: 80_210_000, of: Self.usdc),
                                      readAt: Date(timeIntervalSince1970: 0))
        #expect(book.bestBid < book.mid && book.mid < book.bestAsk)
        // OQ-C12: a spread is how far this price is above the other, so the ask's spread to the mid is positive
        #expect(book.bestAsk.spread(to: book.mid) > .zero)
    }

    @Test func anOrderResultCarriesTheExchangesIdAndWords() {
        let filled = ExchangeClientOrderResult.filled(units: Amount(baseUnits: 15, asset: Self.btc), at: Self.mid, id: 42, time: .distantPast)
        #expect(filled != .partlyFilled(units: Amount(baseUnits: 15, asset: Self.btc), at: Self.mid, id: 42, time: .distantPast))
        #expect(ExchangeClientOrderResult<Int>.refused(code: "EOrder", text: "Insufficient funds")
            == .refused(code: "EOrder", text: "Insufficient funds"))
        #expect(ExchangeClientOrderResult<Int>.cancelledBeforeAccepted != .cancelled(id: 42))
        #expect(ExchangeClientOrderResult<Int>.resting(id: 42, time: .distantPast) != .cancelled(id: 42))
        #expect(ExchangeClientOrderResult<Int>.resting(id: 42, time: .distantPast) == .resting(id: 42, time: .distantPast))
    }

    @Test func aLedgerItemCarriesItsCursor() {
        let fee = Amount(baseUnits: 2_500, asset: Self.usdc)
        let item = ExchangeClientLedgerItem<String, Int, Int>.fill(
            market: "BTC", side: .buy, units: Amount(baseUnits: 15, asset: Self.btc), price: Self.mid, fee: fee,
            order: 42, closedBy: .liquidation, time: .distantPast, cursor: 7
        )
        guard case .fill(_, _, _, _, let read, _, let reason, _, let cursor, _) = item else {
            Issue.record("Not a fill")
            return
        }
        #expect(read == fee && reason == .liquidation && cursor == 7)
    }

    // The owner's ruling (2026-10-07): a fill states what it did to the position, typed, FIX's name; nil where the
    // exchange states none.
    @Test func aFillsPositionEffectIsOpenOrCloseByItsCaseNameAndNilWhereNoneIsStated() throws {
        #expect(ExchangeClientPositionEffect.allCases == [.open, .close])
        #expect(try ExchangeClientPositionEffect.close.toJSON() == #""close""#)
        #expect(try #""open""#.fromJSON() == ExchangeClientPositionEffect.open)
        #expect(ExchangeClientPositionEffect.stub() == .open)
        let unstated = ExchangeClientLedgerItem<String, Int, Int>.fill(
            market: "BTC", side: .buy, units: Amount(baseUnits: 15, asset: Self.btc), price: Self.mid,
            fee: Amount(baseUnits: 2_500, asset: Self.usdc), order: 42, closedBy: nil, time: .distantPast, cursor: 7
        )
        guard case .fill(_, _, _, _, _, _, _, _, _, let effect) = unstated else {
            Issue.record("Not a fill")
            return
        }
        #expect(effect == nil)
        let closing = ExchangeClientLedgerItem<String, Int, Int>.fill(
            market: "BTC", side: .sell, units: Amount(baseUnits: 15, asset: Self.btc), price: Self.mid,
            fee: Amount(baseUnits: 2_500, asset: Self.usdc), order: 42, closedBy: nil, time: .distantPast, cursor: 7, positionEffect: .close
        )
        #expect(closing != unstated)
        guard case .fill(_, _, _, _, _, _, _, _, _, .close) = closing else {
            Issue.record("Not a closing fill")
            return
        }
    }

    @Test func theAccountsValuesAreComparedByValue() {
        let mode = ExchangeClientAccountMode(name: "standard", allowsTransfer: true, allowsIsolatedMargin: true, alternatives: [])
        let position = ExchangeClientPosition(market: "BTC", side: .sell, units: Amount(baseUnits: 15, asset: Self.btc),
                                              entryPrice: Self.mid, mark: Self.mid, liquidationPrice: nil)
        let state = ExchangeClientAccountState(balance: Amount(whole: 100, of: Self.usdc), withdrawable: Amount(whole: 90, of: Self.usdc),
                                               positions: [position], mode: mode, readAt: .distantPast)
        #expect(state.positions == [position])
        #expect(ExchangeClientKeyFacts(canTrade: true, canTransfer: true, canWithdraw: false, approvedBy: nil, validUntil: nil)
            != ExchangeClientKeyFacts(canTrade: true, canTransfer: true, canWithdraw: true, approvedBy: nil, validUntil: nil))
        #expect(ExchangeClientRequestBudget(limit: 1_200, remaining: 1_100, resetsAt: .distantPast).remaining == 1_100)
        #expect(ExchangeClientNotice(kind: .delisting, market: "BTC", effectiveAt: .distantPast, text: "delisted").kind == .delisting)
    }

    @Test func noValueCarriesANumberAsText() {
        // § 8.6: every number is § 1's type; the text fields are the exchange's words, never a number.
        // Carried in step 4a of the identity PR: C30's market now hands up the exchange's symbols as facts beside its
        // holdings (design § 5.3), words like its name, and its lot and minimum as optional amounts. Carried in step 4b:
        // its second name is a name.
        let numeric: [Any.Type] = [Amount.self, Amount?.self, Price.self, Fraction.self, Int.self, Int?.self, Date.self]
        let words: Set<String> = ["name", "alternateName", "baseSymbol", "quoteSymbol", "base", "quote", "isPerpetual"]
        let market = ExchangeClientMarket(name: "BTC", base: Self.btc, quote: Self.usdc, lotSize: .zero(of: Self.btc),
                                          minimumOrder: .zero(of: Self.btc), maxLeverage: nil, leverageSet: nil, isPerpetual: false)
        for child in Mirror(reflecting: market).children where !words.contains(child.label ?? "") {
            #expect(numeric.contains { $0 == type(of: child.value) }, "\(child.label ?? "?") is \(type(of: child.value))")
        }
    }
}

// The client gaps of the identity PR: C30's open order carries the consumer's own id back; the forms the plug-ins
// write it in and read it back from.
@Suite("C30: the client order id")
struct ExchangeClientOrderIdTests {
    static let token: UInt128 = 0x0123_4567_89ab_cdef_0011_2233_4455_6677

    @Test func anOpenOrderCarriesTheClientOrderIdItWasPlacedWith() {
        let units = Amount(baseUnits: 15, asset: ExchangeClientValuesTests.btc)
        let placed = ExchangeClientOpenOrder(id: 42, market: "BTC", side: .buy, units: units, clientOrderId: Self.token)
        #expect(placed.clientOrderId == Self.token)
        #expect(placed != ExchangeClientOpenOrder(id: 42, market: "BTC", side: .buy, units: units, clientOrderId: nil))
    }

    @Test func theFormsAreThirtyTwoHexDigitsAndAUUIDsText() {
        #expect(Self.token.clientOrderIdHex == "0123456789abcdef0011223344556677")
        #expect(UInt128(1).clientOrderIdHex == "00000000000000000000000000000001")
        #expect(Self.token.clientOrderIdUUIDText == "01234567-89ab-cdef-0011-223344556677")
    }

    @Test func eachFormReadsBackAndAnyOtherTextDoesNot() {
        for text in ["0x0123456789abcdef0011223344556677", "0123456789ABCDEF0011223344556677", "01234567-89ab-cdef-0011-223344556677"] {
            #expect(UInt128(clientOrderIdText: text) == Self.token, "\(text)")
        }
        for text in ["", "arb-20240509-00010", "11111-000000-000000", "0x0123", "0123456789abcdef00112233445566778", "g123456789abcdef0011223344556677",
                     "0123456789abcdef-0011223344556677", "+123456789abcdef0011223344556677"] {
            #expect(UInt128(clientOrderIdText: text) == nil, "\(text)")
        }
    }
}
