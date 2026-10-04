// WireDecimal.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

// The one parse of a feed's number text in this library (C3: "the digits-to-base-units code exists once, inside
// the clients library at the wire, where AmountError.malformedText and AmountError.belowBaseUnit are thrown").
//
// A response model decodes each number text into a WireDecimal at decode, so no text survives the decode and no
// floating point is ever made; the decimal becomes a Price or an Amount once the market's assets are in hand.
// FOSFoundation's fetch decodes with its own JSONDecoder, which carries no userInfo, so the assets cannot reach the
// decoder itself; this exact intermediate is how the response model stays exact until they join.
//
// The text accepted: an optional "-", one or more ASCII digits, and optionally a "." followed by one or more ASCII
// digits. Anything else (a "+", an exponent, a separator, a space, two points, a bare point) is malformedText.

struct WireDecimal: Hashable, Sendable {
    // The number with its point removed, and how many of its digits were after the point; trailing zeros after
    // the point are stripped, so one number has one WireDecimal.
    let digits: Int128
    let fractionDigits: Int

    init(parsing text: String) throws {
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

        while fractionDigits > 0, digits % 10 == 0 {
            digits /= 10
            fractionDigits -= 1
        }

        self.digits = negative ? -digits : digits
        self.fractionDigits = fractionDigits
    }

    // The number as plain decimal text, for an error's message only.
    var text: String {
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

    /// This number of whole units of `asset`, exactly
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` when the number has more fraction digits than the asset's base unit
    ///   holds; ``AmountError/malformedText`` when it does not fit an amount
    func amount(of asset: Asset) throws -> Amount {
        Amount(baseUnits: try scaled(toExponent: asset.unitExponent), asset: asset)
    }

    /// This number of whole `quote` units per one whole unit of `base`, exactly
    ///
    /// A price holds nine fraction digits below the quote's base unit (the one scale of CryptoAsset), so text finer
    /// than that is ``AmountError/belowBaseUnit`` with the quote's exponent plus nine.
    func price(of quote: Asset, per base: Asset) throws -> Price {
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

    private static func powerOfTen(_ exponent: Int) -> Int128 {
        var result: Int128 = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }
}
