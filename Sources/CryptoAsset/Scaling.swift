// Scaling.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// The full-width arithmetic every scaling in this library goes through (§ 9.4 of the protocols): the product is
// taken at 256 bits by `multipliedFullWidth(by:)` and divided back by `dividingFullWidth(_:)`, so no intermediate
// overflows where the result fits. Swift's integer division truncates, so every result rounds toward zero, for a
// positive and a negative quantity alike. A result that does not fit an Int128 traps.

extension Int128 {
    // The one scale of a Fraction's and a Price's numerator, 10^9 (OQ-C6).
    static let assetScale: Int128 = 1_000_000_000

    // 10^exponent for 0 through 38, the powers that fit an Int128.
    static func powerOfTen(_ exponent: Int) -> Int128 {
        precondition((0...38).contains(exponent), "10^\(exponent) does not fit an Int128")
        var result: Int128 = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }

    // self × multiplier ÷ divisor at full width, toward zero, with the remainder.
    func scaledWithRemainder(by multiplier: Int128, over divisor: Int128) -> (quotient: Int128, remainder: Int128) {
        precondition(divisor != 0, "division by zero")
        return divisor.dividingFullWidth(multipliedFullWidth(by: multiplier))
    }

    // self × multiplier ÷ divisor at full width, toward zero.
    func scaled(by multiplier: Int128, over divisor: Int128) -> Int128 {
        scaledWithRemainder(by: multiplier, over: divisor).quotient
    }

    // self × multiplier ÷ 10^exponent at full width, toward zero, for any exponent up to 39 (a price's scale on
    // top of a 30-exponent asset). Above 38 the divisor does not fit an Int128, so the full-width product is
    // divided by 10^38 first and the quotient by the rest; truncation composes, so the result is the same.
    func scaled(by multiplier: Int128, overPowerOfTen exponent: Int) -> Int128 {
        if exponent <= 38 {
            return scaled(by: multiplier, over: .powerOfTen(exponent))
        }
        let first = scaled(by: multiplier, over: .powerOfTen(38))
        return first / .powerOfTen(exponent - 38)
    }

    // self × multiplier, trapping where the product does not fit.
    func timesExactly(_ multiplier: Int128) -> Int128 {
        let (product, overflow) = multipliedReportingOverflow(by: multiplier)
        precondition(!overflow, "\(self) × \(multiplier) does not fit an Int128")
        return product
    }
}
