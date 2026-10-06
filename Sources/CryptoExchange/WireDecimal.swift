// WireDecimal.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

// The one parse of an exchange's or a feed's number text in this package (C3: "the digits-to-base-units code exists
// once, inside the clients library at the wire, where AmountError.malformedText and AmountError.belowBaseUnit are
// thrown"), and its one way back to text for an order going out (C30: "an order out encodes the same way"). It lives
// in CryptoExchange, the clients' base library, with `package` access, so every client in the package (the exchange
// clients and the OHLCV clients) decodes and encodes through this one type and no consumer of the package sees it.
//
// A response model decodes each number text into a WireDecimal at decode, so no text survives the decode and no
// floating point is ever made; the decimal becomes a Price, an Amount or a Fraction once the market's assets are in
// hand. FOSFoundation's fetch decodes with its own JSONDecoder, which carries no userInfo, so the assets cannot reach
// the decoder itself; this exact intermediate is how the response model stays exact until they join.
//
// The text accepted: an optional "-", one or more ASCII digits, and optionally a "." followed by one or more ASCII
// digits. Anything else (a "+", an exponent, a separator, a space, two points, a bare point) is malformedText.

package struct WireDecimal: Hashable, Sendable {
    // The number with its point removed, and how many of its digits were after the point; trailing zeros after
    // the point are stripped, so one number has one WireDecimal.
    package let digits: Int128
    package let fractionDigits: Int

    package init(parsing text: String) throws {
        var scalars = Substring(text).unicodeScalars[...]
        var negative = false
        if scalars.first == "-" {
            negative = true
            scalars = scalars.dropFirst()
        }

        var digits: Int128 = 0
        var fractionDigits = 0
        var seenPoint = false
        var digitsBeforePoint = 0
        var digitsAfterPoint = 0

        for scalar in scalars {
            switch scalar {
            case "0"..."9":
                let value = Int128(scalar.value - 48)
                let (shifted, overflowA) = digits.multipliedReportingOverflow(by: 10)
                let (sum, overflowB) = shifted.addingReportingOverflow(value)
                guard !overflowA, !overflowB else {
                    throw AmountError.malformedText(text)
                }
                digits = sum
                if seenPoint {
                    digitsAfterPoint += 1
                    fractionDigits += 1
                } else {
                    digitsBeforePoint += 1
                }
            case "." where !seenPoint:
                seenPoint = true
            default:
                throw AmountError.malformedText(text)
            }
        }

        guard digitsBeforePoint > 0, !seenPoint || digitsAfterPoint > 0 else {
            throw AmountError.malformedText(text)
        }

        self.init(digits: negative ? -digits : digits, fractionDigits: fractionDigits)
    }

    // The number digits × 10^−fractionDigits, its trailing fraction zeros stripped.
    package init(digits: Int128, fractionDigits: Int) {
        var digits = digits
        var fractionDigits = fractionDigits
        while fractionDigits > 0, digits % 10 == 0 {
            digits /= 10
            fractionDigits -= 1
        }
        self.digits = digits
        self.fractionDigits = fractionDigits
    }

    /// The amount as decimal text in whole units, exactly: the way an order's size goes out
    package init(_ amount: Amount) {
        self.init(digits: amount.baseUnits, fractionDigits: amount.asset.unitExponent)
    }

    /// The price as decimal text in whole quote units per whole base unit, exactly: the way an order's limit goes out
    ///
    /// A price holds nine digits below the quote's base unit, so its exact decimal has at most the quote's exponent
    /// plus nine fraction digits. The cost of 10^9 whole base units is the price times 10^9 with no rounding, read
    /// back at that many fraction digits.
    package init(_ price: Price) {
        let size = Amount(baseUnits: Self.powerOfTen(9 + price.base.unitExponent), asset: price.base)
        self.init(digits: price.cost(of: size).baseUnits, fractionDigits: price.quote.unitExponent + 9)
    }

    // The number as plain decimal text with no trailing fraction zeros: an error's message, an order's field, a
    // signed payload's field.
    package var text: String {
        let magnitude = digits.magnitude
        var body = String(magnitude)
        if fractionDigits > 0 {
            if body.count <= fractionDigits {
                body = String(repeating: "0", count: fractionDigits - body.count + 1) + body
            }
            body.insert(".", at: body.index(body.endIndex, offsetBy: -fractionDigits))
        }
        return digits < 0 ? "-" + body : body
    }

    /// Halfway between two numbers, exactly: one more fraction digit at most
    package static func midpoint(_ lhs: Self, _ rhs: Self) -> Self {
        let digits = max(lhs.fractionDigits, rhs.fractionDigits)
        let sum = lhs.digits * powerOfTen(digits - lhs.fractionDigits) + rhs.digits * powerOfTen(digits - rhs.fractionDigits)
        return Self(digits: sum * 5, fractionDigits: digits + 1)
    }

    /// This number of whole units of `asset`, exactly
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` when the number has more fraction digits than the asset's base unit
    ///   holds; ``AmountError/malformedText`` when it does not fit an amount
    package func amount(of asset: Asset) throws -> Amount {
        Amount(baseUnits: try scaled(toExponent: asset.unitExponent), asset: asset)
    }

    /// This number of whole `quote` units per one whole unit of `base`, exactly
    ///
    /// A price holds nine fraction digits below the quote's base unit (the one scale of CryptoAsset), so text finer
    /// than that is ``AmountError/belowBaseUnit`` with the quote's exponent plus nine.
    package func price(of quote: Asset, per base: Asset) throws -> Price {
        if fractionDigits <= quote.unitExponent {
            return Price(Amount(baseUnits: try scaled(toExponent: quote.unitExponent), asset: quote), per: base)
        }
        // digits × 10^−fractionDigits whole quote = digits quote base units per 10^(fractionDigits − exponent)
        // whole base units; Price(_:per:) divides that size back out at the scale, exactly while the excess is
        // at most nine digits.
        let excess = fractionDigits - quote.unitExponent
        guard excess <= 9, excess + base.unitExponent <= 38 else {
            throw AmountError.belowBaseUnit(text, unitExponent: quote.unitExponent + 9)
        }
        let size = Amount(baseUnits: Self.powerOfTen(excess + base.unitExponent), asset: base)
        return Price(Amount(baseUnits: digits, asset: quote), per: size)
    }

    /// This number as a fraction, exactly: a funding rate "0.0000125" is 0.00125 %
    ///
    /// A fraction holds nine fraction digits (CryptoAsset's one scale), so text finer than that is
    /// ``AmountError/belowBaseUnit`` at exponent nine.
    package func fraction() throws -> Fraction {
        guard fractionDigits <= 9 else {
            throw AmountError.belowBaseUnit(text, unitExponent: 9)
        }
        // digits ÷ 10^fractionDigits, which Fraction(_:over:) takes at its scale exactly while fractionDigits ≤ 9.
        return Fraction(
            Amount(baseUnits: digits, asset: Self.ratioAsset),
            over: Amount(baseUnits: Self.powerOfTen(fractionDigits), asset: Self.ratioAsset)
        )
    }

    /// This number as a whole count, exactly: a leverage, a count of trades
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` at exponent zero when the number has a fraction; ``AmountError/malformedText``
    ///   when it does not fit an `Int`
    package func integer() throws -> Int {
        guard fractionDigits == 0 else {
            throw AmountError.belowBaseUnit(text, unitExponent: 0)
        }
        guard let value = Int(exactly: digits) else {
            throw AmountError.malformedText(text)
        }
        return value
    }

    private func scaled(toExponent exponent: Int) throws -> Int128 {
        guard fractionDigits <= exponent else {
            throw AmountError.belowBaseUnit(text, unitExponent: exponent)
        }
        let shift = exponent - fractionDigits
        guard shift <= 38 else {
            throw AmountError.malformedText(text)
        }
        let (result, overflow) = digits.multipliedReportingOverflow(by: Self.powerOfTen(shift))
        guard !overflow else {
            throw AmountError.malformedText(text)
        }
        return result
    }

    package static func powerOfTen(_ exponent: Int) -> Int128 {
        var result: Int128 = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }

    // The unit-less asset a ratio's two counts are in, so Fraction(_:over:) can divide them.
    private static let ratioAsset: Asset = {
        do {
            return try Asset(symbol: "RATIO", unitExponent: 0)
        } catch {
            preconditionFailure("The ratio asset is not a valid declaration: \(error)")
        }
    }()
}

extension WireDecimal: Decodable {
    // A number the exchange sends as JSON text, "65000.00", decoded exactly at decode.
    package init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(parsing: container.decode(String.self))
    }
}
