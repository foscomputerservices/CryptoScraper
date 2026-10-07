// C8 — A bar interval, the public OHLCV client's form of a timeframe.
// Projected from docs/fosline-suite-protocols.md C8: "A bar's length as a feed takes it: a count and a unit, never a duration".

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("C8 BarInterval")
struct C8_BarIntervalTests {
    // "a count and a unit"
    @Test func carriesCountAndUnit() {
        let quarterHour = BarInterval(count: 15, unit: .minute)
        #expect(quarterHour.count == 15)
        #expect(quarterHour.unit == .minute)
    }

    // "never a duration" — fifteen minutes is not a quarter of an hour's bar in another unit
    @Test func sameDurationDifferentUnitIsDifferent() {
        #expect(BarInterval(count: 60, unit: .minute) != BarInterval(count: 1, unit: .hour))
        #expect(BarInterval(count: 7, unit: .day) != BarInterval(count: 1, unit: .week))
    }

    // "Codable" — round trip through toJSON() / fromJSON()
    @Test(arguments: [BarInterval.Unit.minute, .hour, .day, .week])
    func roundTrips(_ unit: BarInterval.Unit) throws {
        let interval = BarInterval(count: 4, unit: unit)
        let back: BarInterval = try interval.toJSON().fromJSON()
        #expect(back == interval)
    }
}
