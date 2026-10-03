// Stubs.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The two-stub form on every value of the library: `stub()` for `Stubbable`, calling `stub(…)` with every piece as
// an optional parameter defaulting to the reserved fake. The fakes are self-marking (R11): symbols of the
// Flintstones, 42 where a number is, and an exponent no shipped asset uses.

extension AssetSymbol {
    public static func stub() -> Self { stub(text: nil) }

    public static func stub(text: String? = nil) -> Self {
        do {
            return try AssetSymbol(validating: text ?? "FRED")
        } catch {
            preconditionFailure("AssetSymbol.stub(text:) with a malformed symbol: \(error)")
        }
    }
}

extension Asset {
    /// The reserved-fake asset for a test that does not care which: "FRED" at exponent 4
    public static func stub() -> Self { stub(symbol: nil, unitExponent: nil) }

    /// A stub with any piece overridden, every other piece a reasonable fake, so a test states only what it tests
    ///
    /// ```swift
    /// let eightPlaces = Asset.stub(unitExponent: 8)
    /// ```
    public static func stub(symbol: AssetSymbol? = nil, unitExponent: Int? = nil,
                            wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
                            between: [Unit]? = nil, displayUnit: Unit? = nil) -> Self {
        do {
            return try Asset(
                symbol: symbol ?? .stub(),
                unitExponent: unitExponent ?? 4,
                wholeUnit: wholeUnit ?? .stub(name: "boulder"),
                baseUnit: baseUnit ?? .stub(name: "pebble"),
                between: between ?? [],
                displayUnit: displayUnit
            )
        } catch {
            preconditionFailure("Asset.stub(…) with an override that is not a valid asset: \(error)")
        }
    }
}

extension Asset.Unit {
    public static func stub() -> Self { stub(name: nil) }

    public static func stub(name: String? = nil, exponent: Int? = nil,
                            symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(
            name: name ?? "pebble",
            exponent: exponent ?? 2,
            symbol: symbol,
            fractionDigits: fractionDigits
        )
    }
}

extension Asset.UnitDescription {
    public static func stub() -> Self { stub(name: nil) }

    public static func stub(name: String? = nil, symbol: String? = nil, fractionDigits: Int? = nil) -> Self {
        .init(name: name ?? "pebble", symbol: symbol, fractionDigits: fractionDigits)
    }
}

extension Amount {
    public static func stub() -> Self { stub(baseUnits: nil) }

    public static func stub(baseUnits: Int128? = nil, asset: Asset? = nil) -> Self {
        .init(baseUnits: baseUnits ?? 42, asset: asset ?? .stub())
    }
}

extension Fraction {
    public static func stub() -> Self { stub(percent: nil) }

    // A fraction's numerator is sealed, so its stub overrides the percent it is made from.
    public static func stub(percent: Int? = nil) -> Self {
        .init(percent: percent ?? 42)
    }
}

extension Price {
    public static func stub() -> Self { stub(quote: nil) }

    // 42 whole FRED per one BARNEY: two reserved fakes, so the quote and the base are never one asset.
    public static func stub(quote: Amount? = nil, base: Asset? = nil) -> Self {
        .init(
            quote ?? Amount(whole: 42, of: .stub()),
            per: base ?? .stub(symbol: .stub(text: "BARNEY"))
        )
    }
}

extension BarInterval {
    public static func stub() -> Self { stub(count: nil) }

    public static func stub(count: Int? = nil, unit: Unit? = nil) -> Self {
        .init(count: count ?? 42, unit: unit ?? .minute)
    }
}
