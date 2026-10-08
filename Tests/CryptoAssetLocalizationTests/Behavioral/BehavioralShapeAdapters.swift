// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for CryptoAssetLocalization's second channel (part 6 of the builder's brief of 2026-10-08),
// projected from the inputs file alone. Each maps one call a projected file writes, the `// INVENTED:` lines of
// Values.swift and the design's own initializers as the design wrote them, onto the surface the code declares:
// wiring only, never a behavior. No assertion of a projected file is edited; a red that is not a defect is disabled
// in place with its classification as the reason.

import CryptoAsset
import CryptoAssetLocalization
import FOSFoundation
import FOSMVVM
import Foundation

// MARK: The projected fakes, declared

/// `BehavioralRegistry`: the statement the projected fakes are read from: the library's declarations and three
/// reserved fakes on the bedrock:42 chain, each named by the symbol the projector gave it
///
/// - TKU: 2 decimals, its whole unit signed "$" at 2 fraction digits (the projected `dollar()`)
/// - TKA: 8 decimals, no sign and no whole-unit name, so its display unit reads as its symbol; its base unit named
///   "satoshi" (the projected `eightDecimals()` and `satoshi()`)
/// - TKB: 18 decimals, no unit named (the projected `eighteenDecimals()`)
enum BehavioralRegistry {
    static func instance(_ symbol: String) -> AssetInstance {
        .stub(address: symbol.lowercased())
    }

    static let registry: AssetRegistry = {
        func declaration(_ symbol: String, decimals: Int, wholeUnit: Asset.UnitDescription? = nil,
                         baseUnit: Asset.UnitDescription? = nil) throws -> AssetDeclaration {
            let home = instance(symbol)
            let text = try AssetSymbol(validating: symbol)
            return try AssetDeclaration(
                asset: .stub(home: home), tokenName: symbol, symbol: text,
                wholeUnit: wholeUnit, baseUnit: baseUnit,
                instances: [.init(instance: home, decimals: decimals, symbol: text)]
            )
        }
        do {
            return try AssetRegistry(AssetRegistry.libraryDeclarations + [
                declaration("TKU", decimals: 2, wholeUnit: .init(name: "tku-dollar", symbol: "$", fractionDigits: 2)),
                declaration("TKA", decimals: 8, baseUnit: .init(name: "satoshi")),
                declaration("TKB", decimals: 18)
            ])
        } catch {
            preconditionFailure("BehavioralRegistry: \(error)")
        }
    }()

    static func declaration(of instance: AssetInstance) -> AssetDeclaration {
        do {
            return try registry.declaration(of: registry.asset(of: instance))
        } catch {
            preconditionFailure("BehavioralRegistry.declaration(of: \(instance.id)): \(error)")
        }
    }
}

// MARK: Values.swift's inventions

extension AssetInstance {
    /// The projected `stub(symbol:decimals:displayUnit:)`: the fake declared under `symbol` in
    /// ``BehavioralRegistry``, onto `AssetInstance.stub(chainId:address:)`; the decimals and display unit are the
    /// declaration's, checked here
    static func stub(symbol: String, decimals: Int, displayUnit: Asset.Unit?) -> AssetInstance {
        let instance = BehavioralRegistry.instance(symbol)
        let declaration = BehavioralRegistry.declaration(of: instance)
        precondition(declaration.instances[0].decimals == decimals, "\(symbol) is declared at another decimals")
        precondition(displayUnit == nil || displayUnit == declaration.displayUnit, "\(symbol) has another display unit")
        return instance
    }

    /// The projected `displayUnit`: the declaration's ``AssetDeclaration/displayUnit``
    var displayUnit: Asset.Unit {
        BehavioralRegistry.declaration(of: self).displayUnit
    }
}

extension Asset.Unit {
    /// The projected `stub(sign:decimals:)`: the declared unit of a fake whose sign, or else whose name, is `sign`;
    /// `decimals` is the fraction digits a reader sees in it, checked against the unit
    static func stub(sign: String, decimals: Int) -> Asset.Unit {
        let units = ["TKU", "TKA", "TKB"].flatMap { BehavioralRegistry.declaration(of: BehavioralRegistry.instance($0)).units }
        guard let unit = units.first(where: { $0.symbol == sign }) ?? units.first(where: { $0.symbol == nil && $0.name == sign }) else {
            preconditionFailure("No fake declares a unit \"\(sign)\"")
        }
        precondition((unit.fractionDigits ?? unit.exponent) == decimals, "\"\(sign)\" shows other fraction digits")
        return unit
    }
}

extension Amount {
    /// The projected `Amount(baseUnits:instance:)`: onto `Amount(baseUnits:of:)`
    init(baseUnits: Int, instance: AssetInstance) {
        self.init(baseUnits: Int128(baseUnits), of: instance)
    }

    /// The projected `Amount(baseUnitsDecimalString:instance:)`: the digits read as an `Int128`, onto
    /// `Amount(baseUnits:of:)`
    init(baseUnitsDecimalString digits: String, instance: AssetInstance) {
        guard let baseUnits = Int128(digits) else {
            preconditionFailure("Not an Int128: \(digits)")
        }
        self.init(baseUnits: baseUnits, of: instance)
    }
}

extension Price {
    /// The projected `Price(perWholeBase:quote:base:)`: the quote per one whole base unit as decimal text, onto
    /// `Price(_:per:in:)` over a size
    ///
    /// The quote's text at its decimals plus the price's nine is an exact count of quote base units at the scale;
    /// spread over 10^9 whole units of the base, the price's own division leaves exactly that count as the scaled
    /// number.
    init(perWholeBase decimal: String, quote: AssetInstance, base: AssetInstance) {
        let registry = BehavioralRegistry.registry
        do {
            let quoteDecimals = try registry.decimals(of: quote)
            let baseDecimals = try registry.decimals(of: base)
            let parts = decimal.split(separator: ".", omittingEmptySubsequences: false)
            let whole = String(parts[0])
            let fraction = parts.count > 1 ? String(parts[1]) : ""
            let places = quoteDecimals + 9
            precondition(fraction.count <= places, "\(decimal) has more digits than a price holds")
            let digits = whole + fraction + String(repeating: "0", count: places - fraction.count)
            guard let scaled = Int128(digits) else {
                preconditionFailure("Not a price: \(decimal)")
            }
            var size: Int128 = 1
            for _ in 0..<(baseDecimals + 9) {
                size *= 10
            }
            try self.init(Amount(baseUnits: scaled, of: quote), per: Amount(baseUnits: size, of: base), in: registry)
        } catch {
            preconditionFailure("Price(perWholeBase: \(decimal)): \(error)")
        }
    }
}

/// `LocalizationStore`: the projected `LocalizationStore.empty()`. FOSMVVM's `LocalizationStore` is a protocol, on
/// whose metatype no static member can be called, so this target names a store of its own `LocalizationStore`,
/// shadowing the protocol's name in the projected files only; it conforms to FOSMVVM's protocol and holds no
/// translation. The three types read nothing from a store.
struct LocalizationStore: FOSMVVM.LocalizationStore {
    static func empty() -> LocalizationStore {
        LocalizationStore()
    }

    func keyExists(_ key: String, locale: Locale, index: Int?) -> Bool {
        false
    }

    func translate(_ key: String, locale: Locale, default: String?, index: Int?) -> String? {
        `default`
    }

    func value(_ key: String, locale: Locale, default: Any?, index: Int?) -> Any? {
        `default`
    }
}

// MARK: The design's initializers, as the design wrote them

// The design declares `LocalizableAmount.init(_:in:fractionDigits:showsSymbol:)` and
// `LocalizablePrice.init(_:fractionDigits:)` without `throws` and without a registry: written 2026-10-01, before the
// re-key of 2026-10-06 made an amount `{baseUnits, instance}` with no decimals. On 0.6.1 the library's initializers
// read the registry and throw (a reading for the owner's pen). These two carry the projected calls onto them with
// ``BehavioralRegistry``.

extension LocalizableAmount {
    init(_ value: Amount, in unit: Asset.Unit? = nil, fractionDigits: Int? = nil, showsSymbol: Bool = true) {
        do {
            try self.init(value, in: unit, fractionDigits: fractionDigits, showsSymbol: showsSymbol,
                          in: BehavioralRegistry.registry)
        } catch {
            preconditionFailure("LocalizableAmount(\(value)): \(error)")
        }
    }
}

extension LocalizablePrice {
    init(_ value: Price, fractionDigits: Int? = nil) {
        do {
            try self.init(value, fractionDigits: fractionDigits, in: BehavioralRegistry.registry)
        } catch {
            preconditionFailure("LocalizablePrice(\(value)): \(error)")
        }
    }
}
