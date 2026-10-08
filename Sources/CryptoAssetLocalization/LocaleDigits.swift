// LocaleDigits.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

// The one place this library turns an exact integer into a reader's digits (C10: "rendered from the integer").
//
// The digits are the integer's own decimal text, split at the scale and cut toward zero to the fraction digits the
// reader sees; no Double is formed at any step, so an 18-exponent asset renders every digit and a 39-digit price
// renders all of them. The locale's NumberFormatter supplies the grouping separator, its grouping size, the point,
// the minus and plus signs and the percent symbol; the grouping itself is applied here to the digit text, because a
// NumberFormatter formats through NSNumber, which holds neither an Int128 nor a 30-digit fraction exactly.

/// The separators and signs a locale's number formatting uses, read once per rendering
struct LocaleDigits {
    let groupingSeparator: String
    let groupingSize: Int
    let decimalSeparator: String
    let minusSign: String
    let plusSign: String
    let percentSymbol: String

    init(_ locale: Locale) {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        self.groupingSeparator = formatter.usesGroupingSeparator ? formatter.groupingSeparator : ""
        self.groupingSize = formatter.groupingSize > 0 ? formatter.groupingSize : 3
        self.decimalSeparator = formatter.decimalSeparator
        self.minusSign = formatter.minusSign
        self.plusSign = formatter.plusSign
        self.percentSymbol = formatter.percentSymbol
    }

    /// The text of `magnitude` (a non-negative integer's decimal digits) read at `scale` fraction digits, grouped,
    /// cut toward zero to `fractionDigits`, with the locale's minus before it when `negative`
    func number(digits magnitude: String, scale: Int, fractionDigits: Int, negative: Bool) -> String {
        precondition(scale >= 0 && (0...scale).contains(fractionDigits), "fraction digits outside 0 through the scale")

        // At least one whole digit: 42 at scale 4 is 0.0042.
        let padded = magnitude.count > scale
            ? magnitude
            : String(repeating: "0", count: scale - magnitude.count + 1) + magnitude
        let whole = padded.dropLast(scale)
        // Cut toward zero: the digits past `fractionDigits` are dropped, never rounded.
        let fraction = padded.suffix(scale).prefix(fractionDigits)

        var text = grouped(String(whole))
        if fractionDigits > 0 {
            text += decimalSeparator + fraction
        }
        return negative ? minusSign + text : text
    }

    private func grouped(_ whole: String) -> String {
        guard !groupingSeparator.isEmpty, whole.count > groupingSize else {
            return whole
        }
        var groups: [Substring] = []
        var end = whole.endIndex
        while end > whole.startIndex {
            let start = whole.index(end, offsetBy: -groupingSize, limitedBy: whole.startIndex) ?? whole.startIndex
            groups.insert(whole[start..<end], at: 0)
            end = start
        }
        return groups.joined(separator: groupingSeparator)
    }
}

extension Int128 {
    /// The decimal digits of the magnitude, with no sign: exact at Int128.min
    var magnitudeDigits: String {
        String(magnitude)
    }
}

/// The power of ten of `instance`'s base units in one `unit`, through the public path only
///
/// - Throws: ``AssetError/unitOutOfRange(_:)`` when `unit` is not the asset's or is finer than the instance's base
///   unit; ``AssetRegistryError/undeclaredInstance(_:)``
func exponent(of unit: Asset.Unit, on instance: AssetInstance, in registry: AssetRegistry) throws -> Int {
    // One of the unit, counted in the instance's base units, is 10^exponent exactly.
    try Amount(count: 1, in: unit, of: instance, in: registry).baseUnits.magnitudeDigits.count - 1
}

/// The text a reader sees beside a number in `unit`: the unit's sign; else, for the whole unit, the asset's symbol;
/// else the unit's name ("satoshi")
func symbolText(of unit: Asset.Unit, in declaration: AssetDeclaration) -> String {
    if let sign = unit.symbol {
        return sign
    }
    return unit == declaration.wholeUnit ? declaration.symbol.text : unit.name
}
