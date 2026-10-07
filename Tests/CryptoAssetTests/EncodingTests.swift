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
        let amount = Amount(baseUnits: baseUnits, of: Fixtures.eth)
        let decoded: Amount = try amount.toJSON().fromJSON()
        #expect(decoded == amount)
        #expect(decoded.baseUnits == baseUnits)
        #expect(decoded.instance == Fixtures.eth)
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
        #expect(decoded.quote == price.quote)
        #expect(decoded.base == price.base)
    }

    @Test func theExtremesAreDistinctValues() {
        // so the round trips above are of three different numerators, not one clipped value
        #expect(Set(Fixtures.extremes.map(Fixtures.fraction(atScaled:))).count == 3)
        #expect(Set(Fixtures.extremes.map { Fixtures.price(atScaled: $0) }).count == 3)
    }

    @Test func aQuotedDigitStringIsRejected() throws {
        let quoted = #"{"instance":"iso4217:USD","baseUnits":"42"}"#
        #expect(throws: JSONError.self) {
            let _: Amount = try quoted.fromJSON()
        }
        let bare = #"{"instance":"iso4217:USD","baseUnits":42}"#
        let amount: Amount = try bare.fromJSON()
        #expect(amount == Amount(baseUnits: 42, of: Fixtures.usd))
    }

    @Test func aDeclarationDecodesWithItsUnitsAndDisplayUnit() throws {
        let symbol = try AssetSymbol(validating: "ETH")
        let gweiFirst = try AssetDeclaration(
            asset: .eth, tokenName: "Ethereum", symbol: symbol,
            wholeUnit: .init(name: "ether", symbol: "Ξ"),
            baseUnit: .init(name: "wei"),
            between: [Fixtures.gwei],
            displayUnit: Fixtures.gwei,
            instances: [.init(instance: Fixtures.eth, decimals: 18, symbol: symbol)]
        )
        let decoded: AssetDeclaration = try gweiFirst.toJSON().fromJSON()
        #expect(decoded == gweiFirst)
        #expect(decoded.units == gweiFirst.units)
        #expect(decoded.wholeUnit == gweiFirst.wholeUnit)
        #expect(decoded.baseUnit == gweiFirst.baseUnit)
        #expect(decoded.between == gweiFirst.between)
        #expect(decoded.displayUnit == Fixtures.gwei)
        #expect(decoded.instances == gweiFirst.instances)
    }

    @Test func anAssetIsOneJSONString() throws {
        #expect(try Asset.usd.toJSON() == #""iso4217:USD""#)
        #expect(try #""iso4217:USD""#.fromJSON() == Asset.usd)
    }

    @Test func aMalformedSymbolOrIdInJSONIsADecodingError() throws {
        try expectDecodingError(AssetSymbol.self, from: #""B/TC""#)
        try expectDecodingError(AssetSymbol.self, from: #""""#)
        try expectDecodingError(Asset.self, from: #""U SD""#)
        try expectDecodingError(Asset.self, from: #""iso4217:usd""#)
    }

    @Test func anInstanceDeclarationOutOfRangeInJSONIsADecodingError() throws {
        let instance = try AssetDeclaration.Instance(instance: Fixtures.usdc, decimals: 6, symbol: AssetSymbol(validating: "USDC"))
        let json = try instance.toJSON()
        try expectDecodingError(AssetDeclaration.Instance.self,
                                from: json.replacingOccurrences(of: #""decimals":6"#, with: #""decimals":31"#))
    }

    @Test func otherValuesRoundTrip() throws {
        let symbol = try AssetSymbol(validating: "1inch")
        #expect(try symbol.toJSON().fromJSON() == symbol)
        let interval = BarInterval(count: 15, unit: .minute)
        #expect(try interval.toJSON().fromJSON() == interval)
        let unit = Fixtures.gwei
        #expect(try unit.toJSON().fromJSON() == unit)
    }

    // The one forward-compatibility pin: Amount's encoded shape is its contract (R5, design § 3.5), so its quantity
    // is a bare JSON number at full width beside its instance's id. Fraction's shape is deliberately not pinned.
    @Test func amountsShapeIsPinnedAtTheTwoExtremes() throws {
        let top = try Amount(baseUnits: .max, of: Fixtures.usd).toJSON()
        #expect(top.contains(#""baseUnits":170141183460469231731687303715884105727"#))
        #expect(top.contains(#""instance":"iso4217:USD""#))

        let bottom = try Amount(baseUnits: .min, of: Fixtures.usd).toJSON()
        #expect(bottom.contains(#""baseUnits":-170141183460469231731687303715884105728"#))
        #expect(bottom.contains(#""instance":"iso4217:USD""#))
    }

    // The decode side of the pin: the documented shape (design § 3.5) as committed JSON text, so a change that keeps
    // encoding but breaks decoding is caught.
    @Test func amountsDocumentedShapeDecodesAtTheTwoExtremes() throws {
        let top = #"{"instance":"iso4217:USD","baseUnits":170141183460469231731687303715884105727}"#
        let bottom = #"{"instance":"iso4217:USD","baseUnits":-170141183460469231731687303715884105728}"#
        let decodedTop: Amount = try top.fromJSON()
        let decodedBottom: Amount = try bottom.fromJSON()
        #expect(decodedTop.baseUnits == Int128.max)
        #expect(decodedBottom.baseUnits == Int128.min)
        #expect(decodedTop.instance == Fixtures.usd)
        #expect(decodedBottom.instance == Fixtures.usd)
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
