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
// digits. Anything else (a "+", an exponent, a separator, a space, two points, a bare point), or more digits than
// an Int128 holds, is malformedText.

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
    ///
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when `registry` does not declare the amount's instance
    package init(_ amount: Amount, in registry: AssetRegistry = .shared) throws {
        self.init(digits: amount.baseUnits, fractionDigits: try registry.decimals(of: amount.instance))
    }

    /// The price as decimal text in whole quote units per whole base unit, exactly: the way an order's limit goes out
    ///
    /// A price holds nine digits below the quote's base unit, so its exact decimal has at most the quote's exponent
    /// plus nine fraction digits. The cost of 10^9 whole base units is the price times 10^9 with no rounding, read
    /// back at that many fraction digits.
    ///
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when `registry` does not declare either instance
    package init(_ price: Price, in registry: AssetRegistry = .shared) throws {
        let size = Amount(baseUnits: Self.powerOfTen(9 + (try registry.decimals(of: price.base))), of: price.base)
        self.init(digits: try price.cost(of: size, in: registry).baseUnits,
                  fractionDigits: (try registry.decimals(of: price.quote)) + 9)
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
    ///
    /// The sum, at the finer of the two scales, times five must fit an `Int128`; the arithmetic traps otherwise.
    package static func midpoint(_ lhs: Self, _ rhs: Self) -> Self {
        let digits = max(lhs.fractionDigits, rhs.fractionDigits)
        let sum = lhs.digits * powerOfTen(digits - lhs.fractionDigits) + rhs.digits * powerOfTen(digits - rhs.fractionDigits)
        return Self(digits: sum * 5, fractionDigits: digits + 1)
    }

    /// This number of whole units of `instance`, exactly
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` when the number has more fraction digits than the instance's base unit
    ///   holds; ``AmountError/malformedText`` when it does not fit an amount;
    ///   ``AssetRegistryError/undeclaredInstance(_:)`` when `registry` does not declare `instance`
    package func amount(of instance: AssetInstance, in registry: AssetRegistry = .shared) throws -> Amount {
        Amount(baseUnits: try scaled(toExponent: registry.decimals(of: instance)), of: instance)
    }

    /// This number of whole units of `instance`, cut toward zero at the instance's base unit: an exchange's day turnover,
    /// which it may state finer than its quote asset holds (Hyperliquid's to ten digits for USDC's six), or a base
    /// volume priced at a mid
    ///
    /// - Throws: ``AmountError/malformedText`` when it does not fit an amount;
    ///   ``AssetRegistryError/undeclaredInstance(_:)`` when `registry` does not declare `instance`
    package func amountCutTowardZero(of instance: AssetInstance, in registry: AssetRegistry = .shared) throws -> Amount {
        let decimals = try registry.decimals(of: instance)
        guard fractionDigits > decimals else {
            return try amount(of: instance, in: registry)
        }
        let cut = digits / Self.powerOfTen(fractionDigits - decimals)
        return try Self(digits: cut, fractionDigits: decimals).amount(of: instance, in: registry)
    }

    /// The product of two numbers, exactly: a base volume priced at a mid
    ///
    /// - Throws: ``AmountError/malformedText`` when the product overflows
    package func times(_ other: Self) throws -> Self {
        let (product, overflow) = digits.multipliedReportingOverflow(by: other.digits)
        guard !overflow else {
            throw AmountError.malformedText(text + " × " + other.text)
        }
        return Self(digits: product, fractionDigits: fractionDigits + other.fractionDigits)
    }

    /// This number of whole `quote` units per one whole unit of `base`, exactly
    ///
    /// A price holds nine fraction digits below the quote's base unit (the one scale of CryptoAsset), so text finer
    /// than that is ``AmountError/belowBaseUnit`` with the quote's exponent plus nine.
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` as above, and when the excess digits and the base's exponent pass 38;
    ///   ``AmountError/malformedText`` when it does not fit an amount; ``AssetRegistryError/undeclaredInstance(_:)``
    ///   when `registry` does not declare either instance
    package func price(of quote: AssetInstance, per base: AssetInstance,
                       in registry: AssetRegistry = .shared) throws -> Price {
        let quoteDecimals = try registry.decimals(of: quote)
        let baseDecimals = try registry.decimals(of: base)
        if fractionDigits <= quoteDecimals {
            return try Price(Amount(baseUnits: try scaled(toExponent: quoteDecimals), of: quote), per: base, in: registry)
        }
        // digits × 10^−fractionDigits whole quote = digits quote base units per 10^(fractionDigits − exponent)
        // whole base units; Price(_:per:) divides that size back out at the scale, exactly while the excess is
        // at most nine digits.
        let excess = fractionDigits - quoteDecimals
        guard excess <= 9, excess + baseDecimals <= 38 else {
            throw AmountError.belowBaseUnit(text, decimals: quoteDecimals + 9)
        }
        let size = Amount(baseUnits: Self.powerOfTen(excess + baseDecimals), of: base)
        return try Price(Amount(baseUnits: digits, of: quote), per: size, in: registry)
    }

    /// This number as a fraction, exactly: a funding rate "0.0000125" is 0.00125 %
    ///
    /// A fraction holds nine fraction digits (CryptoAsset's one scale), so text finer than that is
    /// ``AmountError/belowBaseUnit`` at exponent nine.
    package func fraction() throws -> Fraction {
        guard fractionDigits <= 9 else {
            throw AmountError.belowBaseUnit(text, decimals: 9)
        }
        // digits ÷ 10^fractionDigits, which Fraction(_:over:) takes at its scale exactly while fractionDigits ≤ 9.
        return Fraction(
            Amount(baseUnits: digits, of: Self.ratioInstance),
            over: Amount(baseUnits: Self.powerOfTen(fractionDigits), of: Self.ratioInstance)
        )
    }

    /// This number as a whole count, exactly: a leverage, a count of trades
    ///
    /// - Throws: ``AmountError/belowBaseUnit`` at exponent zero when the number has a fraction; ``AmountError/malformedText``
    ///   when it does not fit an `Int`
    package func integer() throws -> Int {
        guard fractionDigits == 0 else {
            throw AmountError.belowBaseUnit(text, decimals: 0)
        }
        guard let value = Int(exactly: digits) else {
            throw AmountError.malformedText(text)
        }
        return value
    }

    private func scaled(toExponent exponent: Int) throws -> Int128 {
        guard fractionDigits <= exponent else {
            throw AmountError.belowBaseUnit(text, decimals: exponent)
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

    // The instance a ratio's two counts are carried in. A ratio counts in no instance, and nothing names one at its
    // call (a funding rate is a ratio of a position, whatever its holding); but Fraction is sealed (its scaled
    // numerator is no initializer's), so Fraction(_:over:), which divides two amounts of one instance by their base
    // units alone and reads no statement, is the one exact door. The carrier is the dollar's home, the library's own
    // constant, never written here as an id (the strings rule); no registry is asked and it plays no part in the result. A reading for the
    // owner's pen, 2026-10-07: a sealed fraction with no instance at all would need a Fraction initializer the
    // design does not name.
    private static let ratioInstance: AssetInstance = {
        do {
            return try AssetInstance(validating: Asset.usd.id)
        } catch {
            preconditionFailure("The dollar's home is not a well-formed instance: \(error)")
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
