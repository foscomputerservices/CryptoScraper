// C8_BarInterval.swift
//
// C8: a bar interval, the public OHLCV client's form of a timeframe: a count and a unit, never a duration.
// Gap: C8 declares no validation; a zero or negative count is neither refused nor said to be allowed, so no
// test is written for it.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("BarInterval — C8 behavioral")
struct C8_BarIntervalTests {

    // C8: init(count:unit:) keeps the count and the unit
    @Test func anIntervalKeepsItsCountAndUnit() {
        let quarterHour = BarInterval(count: 15, unit: .minute)
        #expect(quarterHour.count == 15)
        #expect(quarterHour.unit == .minute)
    }

    // C8: every unit is accepted
    @Test func everyUnitIsKept() {
        for unit in [BarInterval.Unit.minute, .hour, .day, .week] {
            #expect(BarInterval(count: 42, unit: unit).unit == unit)
        }
    }

    // C8: same count and unit are equal and hash alike
    @Test func sameCountAndUnitAreEqual() {
        #expect(BarInterval(count: 4, unit: .hour) == BarInterval(count: 4, unit: .hour))
        #expect(Set([BarInterval(count: 4, unit: .hour), BarInterval(count: 4, unit: .hour)]).count == 1)
    }

    // C8: "never a duration": 60 minutes is not one hour
    @Test func sixtyMinutesIsNotOneHour() {
        #expect(BarInterval(count: 60, unit: .minute) != BarInterval(count: 1, unit: .hour))
    }

    // C8: "never a duration": 7 days is not one week
    @Test func sevenDaysIsNotOneWeek() {
        #expect(BarInterval(count: 7, unit: .day) != BarInterval(count: 1, unit: .week))
    }

    // C8: a different count is a different interval
    @Test func aDifferentCountIsADifferentInterval() {
        #expect(BarInterval(count: 15, unit: .minute) != BarInterval(count: 5, unit: .minute))
    }

    // C8: the four units are distinct
    @Test func theFourUnitsAreDistinct() {
        let units: Set<BarInterval.Unit> = [.minute, .hour, .day, .week]
        #expect(units.count == 4)
    }
}
