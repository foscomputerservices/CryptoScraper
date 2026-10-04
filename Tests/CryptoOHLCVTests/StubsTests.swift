// StubsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing

@Suite("Stubs")
struct StubsTests {
    @Test func theBarStubIsClosedAndItsVolumeIsInThePricesBase() {
        let bar = OHLCVClientBar.stub()
        #expect(bar.isClosed)
        #expect(bar.volume.asset == bar.close.base)
        #expect(bar.volume.baseUnits == 42)
        #expect(bar.trades == 42)
        #expect(bar.openTime == Date(timeIntervalSince1970: 42 * 86_400))
        #expect(bar == .stub(isClosed: true))
        #expect(OHLCVClientBar.stub(isClosed: false).isClosed == false)
    }

    @Test func theMarketStubAgreesWithThePriceStub() {
        let market = BinanceMarket.stub()
        #expect(market.name.text == "FREDBARNEY")
        #expect(market.base == Price.stub().base)
        #expect(market.quote == Price.stub().quote)
    }

    @Test func theOtherStubsAreTheReservedFakes() {
        #expect(OHLCVHistoryGap.stub().missingBarCount == 42)
        #expect(OHLCVHistory.stub().bars == [.stub()])
        #expect(OHLCVHistoryRetrievalResult.stub().requestCount == 42)
        #expect(OHLCVHistoryBackoff.stub().attempts == 42)
    }

    @Test func theBarRoundTripsThroughJSON() throws {
        let bar = OHLCVClientBar.stub(trades: nil)
        let back: OHLCVClientBar = try bar.toJSON().fromJSON()
        #expect(back == bar)
        let gap = OHLCVHistoryGap.stub()
        let gapBack: OHLCVHistoryGap = try gap.toJSON().fromJSON()
        #expect(gapBack == gap)
    }
}
