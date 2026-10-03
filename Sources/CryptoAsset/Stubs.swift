// Stubs.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The two-stub form on every value of the library: `stub()` for `Stubbable`, delegating to `stub(…)`, which takes every
// piece of the value's public initializer as a parameter defaulting to its own type's stub, or to the reserved fake. The fakes are self-marking (R11): symbols of the
// Flintstones, 42 where a number is, and an exponent no shipped asset uses.

extension AssetSymbol {
    public static func stub() -> Self { .stub(text: "FRED") }

    public static func stub(text: String = "FRED") -> Self {
        do {
            return try AssetSymbol(validating: text)
        } catch {
            preconditionFailure("AssetSymbol.stub(text:) with a malformed symbol: \(error)")
        }
    }
}

extension Asset {
    /// The reserved-fake asset for a test that does not care which: "FRED" at exponent 4
    public static func stub() -> Self { .stub(symbol: .stub()) }

    /// A stub with any piece overridden, every other piece a reasonable fake, so a test states only what it tests
    ///
    /// ```swift
    /// let eightPlaces = Asset.stub(unitExponent: 8)
    /// ```
    public static func stub(symbol: AssetSymbol = .stub(), unitExponent: Int = 4,
                            wholeUnit: UnitDescription? = .stub(name: "boulder"),
                            baseUnit: UnitDescription? = .stub(name: "pebble"),
                            between: [Unit] = [], displayUnit: Unit? = nil) -> Self {
        do {
            return try Asset(
                symbol: symbol,
                unitExponent: unitExponent,
                wholeUnit: wholeUnit,
                baseUnit: baseUnit,
                between: between,
                displayUnit: displayUnit
            )
        } catch {
            preconditionFailure("Asset.stub(…) with an override that is not a valid asset: \(error)")
        }
    }
}

extension Asset.Unit {
    public static func stub() -> Self { .stub(name: "pebble") }

    public static func stub(name: String = "pebble", exponent: Int = 2,
                            symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(name: name, exponent: exponent, symbol: symbol, fractionDigits: fractionDigits)
    }
}

extension Asset.UnitDescription {
    public static func stub() -> Self { .stub(name: "pebble") }

    public static func stub(name: String = "pebble", symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(name: name, symbol: symbol, fractionDigits: fractionDigits)
    }
}

extension Amount {
    public static func stub() -> Self { .stub(baseUnits: 42) }

    public static func stub(baseUnits: Int128 = 42, asset: Asset = .stub()) -> Self {
        .init(baseUnits: baseUnits, asset: asset)
    }
}

extension Fraction {
    public static func stub() -> Self { .stub(percent: 42) }

    // A fraction's numerator is sealed, so its stub takes the percent it is made from.
    public static func stub(percent: Int = 42) -> Self {
        .init(percent: percent)
    }
}

extension Price {
    public static func stub() -> Self { .stub(quote: Amount(whole: 42, of: .stub())) }

    // 42 whole FRED per one BARNEY: two reserved fakes, so the quote and the base are never one asset.
    public static func stub(
        quote: Amount = Amount(whole: 42, of: .stub()),
        base: Asset = .stub(symbol: .stub(text: "BARNEY"))
    ) -> Self {
        .init(quote, per: base)
    }
}

extension BarInterval {
    public static func stub() -> Self { .stub(count: 42) }

    public static func stub(count: Int = 42, unit: Unit = .minute) -> Self {
        .init(count: count, unit: unit)
    }
}
