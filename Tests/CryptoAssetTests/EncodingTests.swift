// EncodingTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Encoding")
struct EncodingTests {
    @Test(arguments: Fixtures.extremes)
    func anAmountRoundTrips(baseUnits: Int128) throws {
        let amount = Amount(baseUnits: baseUnits, asset: .eth)
        let decoded: Amount = try amount.toJSON().fromJSON()
        #expect(decoded == amount)
        #expect(decoded.baseUnits == baseUnits)
        #expect(decoded.asset.units == amount.asset.units)
    }

    @Test(arguments: Fixtures.extremes)
    func aFractionRoundTrips(numerator: Int128) throws {
        let fraction = Fixtures.fraction(atScaled: numerator)
        let decoded: Fraction = try fraction.toJSON().fromJSON()
        #expect(decoded == fraction)
    }

    @Test(arguments: Fixtures.extremes)
    func aPriceRoundTrips(numerator: Int128) throws {
        let price = Fixtures.price(atScaled: numerator)
        let decoded: Price = try price.toJSON().fromJSON()
        #expect(decoded == price)
        #expect(decoded.quote.units == price.quote.units)
        #expect(decoded.base.units == price.base.units)
    }

    @Test func theExtremesAreDistinctValues() {
        // so the round trips above are of three different numerators, not one clipped value
        #expect(Set(Fixtures.extremes.map(Fixtures.fraction(atScaled:))).count == 3)
        #expect(Set(Fixtures.extremes.map(Fixtures.price(atScaled:))).count == 3)
    }

    @Test func aQuotedDigitStringIsRejected() throws {
        let asset = try Asset.usd.toJSON()
        let quoted = #"{"baseUnits":"42","asset":\#(asset)}"#
        #expect(throws: JSONError.self) {
            let _: Amount = try quoted.fromJSON()
        }
        let bare = #"{"baseUnits":42,"asset":\#(asset)}"#
        let amount: Amount = try bare.fromJSON()
        #expect(amount == Amount(baseUnits: 42, asset: .usd))
    }

    @Test func anAssetDecodesWithItsUnitsAndDisplayUnit() throws {
        let gweiFirst = try Asset(
            symbol: "ETH", unitExponent: 18,
            wholeUnit: .init(name: "ether", symbol: "Ξ"),
            baseUnit: .init(name: "wei"),
            between: [Fixtures.gwei],
            displayUnit: Fixtures.gwei
        )
        let decoded: Asset = try gweiFirst.toJSON().fromJSON()
        #expect(decoded == gweiFirst)
        #expect(decoded.units == gweiFirst.units)
        #expect(decoded.wholeUnit == gweiFirst.wholeUnit)
        #expect(decoded.baseUnit == gweiFirst.baseUnit)
        #expect(decoded.between == gweiFirst.between)
        #expect(decoded.displayUnit == Fixtures.gwei)

        let usd: Asset = try Asset.usd.toJSON().fromJSON()
        #expect(usd.units == Asset.usd.units)
        #expect(usd.displayUnit == Asset.usd.displayUnit)
    }

    @Test func aMalformedSymbolInJSONIsADecodingError() throws {
        try expectDecodingError(AssetSymbol.self, from: #""B/TC""#)
        try expectDecodingError(AssetSymbol.self, from: #""""#)

        let asset = try Asset.usd.toJSON()
        try expectDecodingError(Asset.self, from: asset.replacingOccurrences(of: #""USD""#, with: #""U SD""#))
    }

    @Test func anAssetOutOfRangeInJSONIsADecodingError() throws {
        let asset = try Asset.usdc.toJSON()
        try expectDecodingError(Asset.self, from: asset.replacingOccurrences(of: #""unitExponent":6"#, with: #""unitExponent":31"#))
    }

    @Test func otherValuesRoundTrip() throws {
        let symbol = try AssetSymbol(validating: "1inch")
        #expect(try symbol.toJSON().fromJSON() == symbol)
        let interval = BarInterval(count: 15, unit: .minute)
        #expect(try interval.toJSON().fromJSON() == interval)
        let unit = Fixtures.gwei
        #expect(try unit.toJSON().fromJSON() == unit)
    }

    // The one forward-compatibility pin: Amount's encoded shape is its contract (R5), so its quantity is a bare
    // JSON number at full width beside its asset. Fraction's and Price's shapes are deliberately not pinned.
    @Test func amountsShapeIsPinnedAtTheTwoExtremes() throws {
        let top = try Amount(baseUnits: .max, asset: .usd).toJSON()
        #expect(top.contains(#""baseUnits":170141183460469231731687303715884105727"#))
        #expect(top.contains(#""asset":{"#))

        let bottom = try Amount(baseUnits: .min, asset: .usd).toJSON()
        #expect(bottom.contains(#""baseUnits":-170141183460469231731687303715884105728"#))
        #expect(bottom.contains(#""asset":{"#))
    }

    // The decode side of the pin: the documented shape (§ 9.7) as committed JSON text, so a change that keeps
    // encoding but breaks decoding is caught. The asset is a committed text too, at exponent 2.
    @Test func amountsDocumentedShapeDecodesAtTheTwoExtremes() throws {
        let asset = #"{"unitExponent":2,"wholeUnit":{"exponent":2,"name":"dollar","symbol":"$","fractionDigits":2},"baseUnit":{"name":"cent","symbol":"¢","exponent":0},"between":[],"displayUnit":{"name":"dollar","symbol":"$","exponent":2,"fractionDigits":2},"symbol":"USD"}"#
        let top = #"{"baseUnits":170141183460469231731687303715884105727,"asset":"# + asset + "}"
        let bottom = #"{"baseUnits":-170141183460469231731687303715884105728,"asset":"# + asset + "}"
        let decodedTop: Amount = try top.fromJSON()
        let decodedBottom: Amount = try bottom.fromJSON()
        #expect(decodedTop.baseUnits == Int128.max)
        #expect(decodedBottom.baseUnits == Int128.min)
        #expect(decodedTop.asset == .usd)
        #expect(decodedBottom.asset == .usd)
    }

    private func expectDecodingError<T: Decodable>(_ type: T.Type, from json: String,
                                                   sourceLocation: SourceLocation = #_sourceLocation) throws {
        do {
            let _: T = try json.fromJSON()
            Issue.record("decoded \(json) as \(T.self)", sourceLocation: sourceLocation)
        } catch JSONError.decodingError {
            // a DecodingError, wrapped by FOSFoundation's fromJSON()
        } catch {
            Issue.record("expected a DecodingError, got \(error)", sourceLocation: sourceLocation)
        }
    }
}
