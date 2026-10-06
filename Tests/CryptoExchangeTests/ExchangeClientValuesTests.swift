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
                                      volume: Amount(whole: 1_234, of: Self.btc), readAt: Date(timeIntervalSince1970: 0))
        #expect(book.bestBid < book.mid && book.mid < book.bestAsk)
        #expect(book.bestAsk.spread(to: book.mid) > .zero  // OQ-C12: how far the ask is above the mid)
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
        guard case .fill(_, _, _, _, let read, _, let reason, _, let cursor) = item else {
            Issue.record("Not a fill")
            return
        }
        #expect(read == fee && reason == .liquidation && cursor == 7)
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
        let numeric: [Any.Type] = [Amount.self, Price.self, Fraction.self, Int.self, Int?.self, Date.self]
        let market = ExchangeClientMarket(name: "BTC", base: Self.btc, quote: Self.usdc, lotSize: .zero(of: Self.btc),
                                          minimumOrder: .zero(of: Self.btc), maxLeverage: nil, leverageSet: nil, isPerpetual: false)
        for child in Mirror(reflecting: market).children where child.label != "name" && child.label != "base" && child.label != "quote" && child.label != "isPerpetual" {
            #expect(numeric.contains { $0 == type(of: child.value) }, "\(child.label ?? "?") is \(type(of: child.value))")
        }
    }
}
