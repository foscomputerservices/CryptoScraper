// BehavioralFixtures.swift
//
// Reserved-fake assets for the behavioral suite, built only through the declared public path.
// Every trap test is paired with a passing test that builds the same fixtures, so a fixture that
// failed to build would show red there and never hide behind an expected exit.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

enum Fake {
    /// FRED at exponent 4, no unit names: the whole unit is named by the symbol, the base unit is unnamed
    static let fred: Asset = try! Asset(symbol: "FRED", unitExponent: 4)

    /// FRED at exponent 4 again, this time with names: the same asset by identity
    static let fredNamed: Asset = try! Asset(
        symbol: "FRED", unitExponent: 4,
        wholeUnit: .init(name: "fred", symbol: "₣", fractionDigits: 4),
        baseUnit: .init(name: "flintstone")
    )

    /// FRED at exponent 8: the same symbol, a different exponent, so a different asset
    static let fredAtEight: Asset = try! Asset(symbol: "FRED", unitExponent: 8)

    /// BARNEY at exponent 8, a named whole unit and a named base unit
    static let barney: Asset = try! Asset(
        symbol: "BARNEY", unitExponent: 8,
        wholeUnit: .init(name: "barney", symbol: "Ƀ", fractionDigits: 8),
        baseUnit: .init(name: "rubble")
    )

    /// The unit named between SLATE's base and whole
    static let pebble = Asset.Unit(name: "pebble", exponent: 9)

    /// SLATE at exponent 18, a whole unit, a base unit, and one unit between
    static let slate: Asset = try! Asset(
        symbol: "SLATE", unitExponent: 18,
        wholeUnit: .init(name: "slate", symbol: "Ϟ"),
        baseUnit: .init(name: "gravel"),
        between: [Fake.pebble]
    )

    /// DINO at exponent 0: its whole unit is its base unit
    static let dino: Asset = try! Asset(symbol: "DINO", unitExponent: 0)

    /// BEDROCK at exponent 30, the widest exponent allowed
    static let bedrock: Asset = try! Asset(symbol: "BEDROCK", unitExponent: 30)
}

/// 10 ^ n as an `Int128`, computed by repeated multiplication
func pow10(_ n: Int) -> Int128 {
    var result: Int128 = 1
    for _ in 0..<n { result *= 10 }
    return result
}

/// Encodes with FOSFoundation's `toJSON()` and decodes with `fromJSON()`
func roundTrip<T: Codable>(_ value: T) throws -> T {
    let json = try value.toJSON()
    return try json.fromJSON()
}

/// True when `error` is ``AssetSymbolError/malformed(_:)``, whatever text it carries
func isMalformed(_ error: AssetSymbolError?) -> Bool {
    guard let error else { return false }
    if case .malformed = error { return true }
    return false
}

/// True when `error` is FOSFoundation's wrapper of a `DecodingError`
func isDecodingError(_ error: JSONError?) -> Bool {
    guard let error else { return false }
    if case .decodingError = error { return true }
    return false
}
