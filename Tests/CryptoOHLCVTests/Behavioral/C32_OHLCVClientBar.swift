// C32_OHLCVClientBar.swift — C32 and § 8.6: the bar's nine properties, their types, no text, its stubs

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("C32: OHLCVClientBar")
struct C32_OHLCVClientBarTests {
    @Test("C32: the bar declares its nine properties with their declared types")
    func nineTypedProperties() {
        let openTime: KeyPath<OHLCVClientBar, Date> = \.openTime
        let closeTime: KeyPath<OHLCVClientBar, Date> = \.closeTime
        let open: KeyPath<OHLCVClientBar, Price> = \.open
        let high: KeyPath<OHLCVClientBar, Price> = \.high
        let low: KeyPath<OHLCVClientBar, Price> = \.low
        let close: KeyPath<OHLCVClientBar, Price> = \.close
        let volume: KeyPath<OHLCVClientBar, Amount> = \.volume
        let trades: KeyPath<OHLCVClientBar, Int?> = \.trades
        let isClosed: KeyPath<OHLCVClientBar, Bool> = \.isClosed
        let paths: [AnyKeyPath] = [openTime, closeTime, open, high, low, close, volume, trades, isClosed]
        #expect(Set(paths).count == 9)
    }

    @Test("C32: the bar stores exactly nine values")
    func exactlyNineStored() {
        #expect(Mirror(reflecting: OHLCVClientBar.stub()).children.count == 9)
    }

    @Test("§ 8.6: no property of the bar is a String")
    func noStringProperty() {
        let children = Mirror(reflecting: OHLCVClientBar.stub()).children
        #expect(children.allSatisfy { !($0.value is String) && !($0.value is String?) })
    }

    @Test("C32 with C7: the stub's volume is counted in its prices' base asset, and its four prices share one market")
    func stubAgrees() {
        let bar = OHLCVClientBar.stub()
        #expect(bar.volume.asset == bar.open.base)
        for price in [bar.high, bar.low, bar.close] {
            #expect(price.base == bar.open.base)
            #expect(price.quote == bar.open.quote)
        }
    }

    @Test("C32 with C7: the parameterized stub overrides only what it is given")
    func stubOverrides() {
        let open = OHLCVClientBar.stub(isClosed: false)
        let closed = OHLCVClientBar.stub(isClosed: true)
        #expect(open.isClosed == false)
        #expect(closed.isClosed == true)
        #expect(open.openTime == closed.openTime)
        #expect(open.close == closed.close)
    }

    @Test("C32: the bar is Hashable; two bars differing only in isClosed are two values")
    func hashable() {
        #expect(OHLCVClientBar.stub() == OHLCVClientBar.stub())
        #expect(OHLCVClientBar.stub(isClosed: false) != OHLCVClientBar.stub(isClosed: true))
        #expect(Set([OHLCVClientBar.stub(isClosed: false), OHLCVClientBar.stub(isClosed: true)]).count == 2)
    }
}
