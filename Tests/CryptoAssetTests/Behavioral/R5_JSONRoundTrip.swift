// R5_JSONRoundTrip.swift
//
// R5: one exact JSON encoding, decodable by Swift's JSONDecoder. The quantity is carried exactly; the asset
// is carried as a value. C3: "Encodes as its base units and its asset, so a stored value says what its own
// balance is." These tests assert identity after a round trip, never the encoded shape.
// Gap: R5's "on both drivers" (Postgres JSONB and SQLite text) is outside this library's tests.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("JSON round trip — R5, C1–C5, C8 behavioral")
struct R5_JSONRoundTripTests {

    // MARK: Amount, exact at full width

    // R5: an ordinary amount survives a round trip
    @Test func anAmountRoundTrips() throws {
        let amount = Amount(baseUnits: 42, asset: Fake.barney)
        let decoded = try roundTrip(amount)
        #expect(decoded == amount)
        #expect(decoded.baseUnits == 42)
        #expect(decoded.asset == Fake.barney)
    }

    // R5: a negative amount survives
    @Test func aNegativeAmountRoundTrips() throws {
        let amount = Amount(baseUnits: -42, asset: Fake.fred)
        #expect(try roundTrip(amount) == amount)
    }

    // R5: zero survives
    @Test func aZeroAmountRoundTrips() throws {
        let amount = Amount.zero(of: Fake.dino)
        #expect(try roundTrip(amount) == amount)
    }

    // R5, R2: "carry the quantity exactly": the largest Int128 survives
    @Test func theLargestAmountRoundTripsExactly() throws {
        let amount = Amount(baseUnits: .max, asset: Fake.bedrock)
        #expect(try roundTrip(amount).baseUnits == Int128.max)
    }

    // R5, R2: the smallest Int128 survives
    @Test func theSmallestAmountRoundTripsExactly() throws {
        let amount = Amount(baseUnits: .min, asset: Fake.bedrock)
        #expect(try roundTrip(amount).baseUnits == Int128.min)
    }

    // R5: a count past a Double's exact range survives, digit for digit
    @Test func aCountPastADoublesPrecisionRoundTripsExactly() throws {
        let count = pow10(30) + 1
        let amount = Amount(baseUnits: count, asset: Fake.bedrock)
        #expect(try roundTrip(amount).baseUnits == count)
    }

    // R5, C3: "a stored value says what its own balance is": the asset's units survive with the amount
    @Test func anAmountsAssetKeepsItsUnitsThroughARoundTrip() throws {
        let decoded = try roundTrip(Amount(whole: 42, of: Fake.slate))
        #expect(decoded.asset.wholeUnit == Fake.slate.wholeUnit)
        #expect(decoded.asset.baseUnit == Fake.slate.baseUnit)
        #expect(decoded.asset.between == Fake.slate.between)
    }

    // R5: "decodable by Swift's JSONDecoder": plain Foundation coders, no FOSFoundation configuration
    @Test func anAmountRoundTripsThroughPlainFoundationCoders() throws {
        let amount = Amount(baseUnits: -pow10(30) - 42, asset: Fake.bedrock)
        let data = try JSONEncoder().encode(amount)
        let decoded = try JSONDecoder().decode(Amount.self, from: data)
        #expect(decoded == amount)
        #expect(decoded.baseUnits == amount.baseUnits)
    }

    // MARK: Asset and its units

    // C2: an asset survives, with every unit
    @Test func anAssetRoundTripsWithEveryUnit() throws {
        let asset = try Asset(symbol: "SLATE", unitExponent: 18,
                              wholeUnit: .init(name: "slate", symbol: "Ϟ", fractionDigits: 6),
                              baseUnit: .init(name: "gravel", symbol: "g"),
                              between: [Fake.pebble],
                              displayUnit: Fake.pebble)
        let decoded = try roundTrip(asset)
        #expect(decoded == asset)
        #expect(decoded.symbol == asset.symbol)
        #expect(decoded.unitExponent == 18)
        #expect(decoded.wholeUnit == asset.wholeUnit)
        #expect(decoded.baseUnit == asset.baseUnit)
        #expect(decoded.between == asset.between)
        #expect(decoded.displayUnit == Fake.pebble)
        #expect(decoded.units == asset.units)
    }

    // C2: an asset with no names survives, still never without a unit
    @Test func anAssetWithoutNamesRoundTrips() throws {
        let decoded = try roundTrip(Fake.fred)
        #expect(decoded == Fake.fred)
        #expect(decoded.baseUnit == nil)
        #expect(decoded.wholeUnit.name == "FRED")
        #expect(decoded.displayUnit == decoded.wholeUnit)
    }

    // C2: a unit survives
    @Test func aUnitRoundTrips() throws {
        let unit = Asset.Unit(name: "pebble", exponent: 9, symbol: "ᵽ", fractionDigits: 2)
        #expect(try roundTrip(unit) == unit)
    }

    // C2: a unit description survives
    @Test func aUnitDescriptionRoundTrips() throws {
        let description = Asset.UnitDescription(name: "fred", symbol: "₣", fractionDigits: 4)
        #expect(try roundTrip(description) == description)
    }

    // C2: the well-known constants survive
    @Test func theWellKnownAssetsRoundTrip() throws {
        for asset in [Asset.usd, .usdc, .usdt, .btc, .eth] {
            let decoded = try roundTrip(asset)
            #expect(decoded == asset)
            #expect(decoded.units == asset.units)
        }
    }

    // MARK: Fraction and Price

    // R7: "Codable the same way as R5": a fraction survives
    @Test func aFractionRoundTrips() throws {
        for fraction in [Fraction.zero, .one, Fraction(basisPoints: 25), Fraction(percent: -2), Fraction(integer: 42)] {
            #expect(try roundTrip(fraction) == fraction)
        }
    }

    // R7: a fraction rounded at the scale survives with its every digit
    @Test func aRoundedFractionRoundTripsExactly() throws {
        let third = Fraction(Amount(baseUnits: 1, asset: Fake.fred), over: Amount(baseUnits: 3, asset: Fake.fred))
        let decoded = try roundTrip(third)
        #expect(decoded == third)
        #expect((Amount(baseUnits: 3_000_000_000, asset: Fake.fred) * decoded).baseUnits == 999_999_999)
    }

    // C5: a price survives, with both its assets
    @Test func aPriceRoundTrips() throws {
        let price = Price(Amount(whole: 42, of: Fake.fred), per: Fake.barney)
        let decoded = try roundTrip(price)
        #expect(decoded == price)
        #expect(decoded.quote == Fake.fred)
        #expect(decoded.base == Fake.barney)
    }

    // C5: a sub-unit price survives exactly
    @Test func aSubUnitPriceRoundTripsExactly() throws {
        let fill = Price(Amount(baseUnits: 4_000, asset: Fake.barney), per: Amount(whole: 10_000, of: Fake.dino))
        let decoded = try roundTrip(fill)
        #expect(decoded == fill)
        #expect(decoded.cost(of: Amount(whole: 5, of: Fake.dino)).baseUnits == 2)
    }

    // MARK: AssetSymbol and BarInterval

    // C1: a symbol survives
    @Test func aSymbolRoundTrips() throws {
        let symbol = try AssetSymbol(validating: "BAMM-BAMM")
        #expect(try roundTrip(symbol) == symbol)
    }

    // C8: every bar interval unit survives
    @Test func everyBarIntervalRoundTrips() throws {
        for unit in [BarInterval.Unit.minute, .hour, .day, .week] {
            let interval = BarInterval(count: 42, unit: unit)
            #expect(try roundTrip(interval) == interval)
        }
    }
}
