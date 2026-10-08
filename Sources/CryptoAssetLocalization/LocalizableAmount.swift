// LocalizableAmount.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import FOSMVVM
import Foundation

// The design's C10 (docs/fosline-suite-protocols.md § 2), on 0.6.1's Amount: an amount is `{baseUnits, instance}`
// and carries no decimals, so the unit's place on the instance and the text beside the number are read from the
// registry when the value is made, and carried with it, so that neither the localizing encode on the server nor a
// decode on a client needs a registry.

/// An ``Amount`` for a reader: grouped, with the locale's point, in a named unit or the whole unit
///
/// A factory makes one from an amount it loaded; the localizing encoder renders it on the server:
///
/// ```swift
/// @ViewModel public struct AssetViewModel {
///     public let balance: LocalizableAmount          // "1,234.56 $" here, "1.234,56 $" in Berlin
///     public let size:    LocalizableAmount          // "0.00012500 ₿"
/// }
/// try LocalizableAmount(stake)                               // the asset's display unit, its fraction digits
/// try LocalizableAmount(size, in: satoshi)                  // "12,500 satoshi"
/// try LocalizableAmount(gain, fractionDigits: 2)            // "9,750.00 $", cut toward zero for the reader
/// try LocalizableAmount(fee, showsSymbol: false)            // in a column whose header names the asset
/// ```
///
/// The exact amount stays available as `value`; the text is the localization's.
///
/// - The whole part is grouped by the locale's separator; the fraction digits are the exact base-unit digits, cut
///   toward zero to ``fractionDigits``, joined by the locale's point. No `Double` is formed at any step, so an
///   18-exponent asset renders every digit.
/// - The symbol is the unit's sign or the asset's symbol as text, never a currency code the formatter looks up:
///   `NumberFormatter`'s currency style knows ISO fiats and nothing of USDC or BTC. A unit with no sign that is not
///   the whole unit shows its name.
/// - A negative amount carries the locale's minus before the number.
public struct LocalizableAmount: LocalizableValue, Comparable {
    /// The exact amount
    public let value: Amount
    /// The unit the text is in: the asset's display unit unless one is given
    public let unit: Asset.Unit
    /// How many fraction digits the reader sees: the unit's default, or the asset's exponent, never more than the exponent
    public let fractionDigits: Int
    /// Whether the unit's sign or the asset's symbol follows the number
    public let showsSymbol: Bool

    // The power of ten of the instance's base units in one `unit`, and the text beside the number: read from the
    // registry when the value is made.
    private let unitExponent: Int
    private let symbol: String
    private let text: String?

    /// An amount for a reader, in `unit` or the asset's display unit
    ///
    /// - Parameters:
    ///   - value: The exact amount
    ///   - unit: The unit the text is in; `nil` for the asset's display unit
    ///   - fractionDigits: How many fraction digits the reader sees; `nil` for the unit's default, or all of them.
    ///     Never more than the unit's exponent on the amount's instance, never fewer than none
    ///   - showsSymbol: Whether the unit's sign or the asset's symbol follows the number
    ///   - registry: The statement the amount's instance, its asset and its units are read from
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when the amount's instance is not declared;
    ///   ``AssetError/unitOutOfRange(_:)`` when `unit` is not the asset's or is finer than the instance's base unit
    public init(_ value: Amount, in unit: Asset.Unit? = nil, fractionDigits: Int? = nil, showsSymbol: Bool = true,
                in registry: AssetRegistry = .shared) throws {
        let declaration = try registry.declaration(of: registry.asset(of: value.instance))
        let unit = unit ?? declaration.displayUnit
        let unitExponent = try exponent(of: unit, on: value.instance, in: registry)
        self.init(
            value: value,
            unit: unit,
            fractionDigits: fractionDigits ?? unit.fractionDigits ?? unitExponent,
            showsSymbol: showsSymbol,
            unitExponent: unitExponent,
            symbol: symbolText(of: unit, in: declaration),
            text: nil
        )
    }

    private init(value: Amount, unit: Asset.Unit, fractionDigits: Int, showsSymbol: Bool, unitExponent: Int,
                 symbol: String, text: String?) {
        self.value = value
        self.unit = unit
        self.fractionDigits = min(max(fractionDigits, 0), unitExponent)
        self.showsSymbol = showsSymbol
        self.unitExponent = unitExponent
        self.symbol = symbol
        self.text = text
    }

    /// The amount's text in `locale`: the number in ``unit``, cut toward zero to ``fractionDigits``, then the symbol
    ///
    /// Needs nothing from `store`: the separators and signs are the locale's, the symbol is the declaration's.
    public func localized(in locale: Locale, store: LocalizationStore) throws -> String? {
        rendered(in: locale)
    }

    private func rendered(in locale: Locale) -> String {
        let number = LocaleDigits(locale).number(
            digits: value.baseUnits.magnitudeDigits,
            scale: unitExponent,
            fractionDigits: fractionDigits,
            negative: value.isNegative
        )
        return showsSymbol ? number + " " + symbol : number
    }

    // MARK: Localizable

    /// Never empty: an amount always has a number
    public var isEmpty: Bool {
        false
    }

    /// ``LocalizableStatus/localized`` once a localizing encode has run, or the value was decoded from one
    public var localizationStatus: LocalizableStatus {
        text == nil ? .localizationPending : .localized
    }

    /// The text the localizing encode produced
    ///
    /// - Throws: ``LocalizerError/localizationUnbound`` before a localizing encode
    public var localizedString: String {
        get throws {
            guard let text else {
                throw LocalizerError.localizationUnbound
            }
            return text
        }
    }

    /// The value and how it is shown: its base units, its instance, the unit, the fraction digits and the symbol's
    /// presence
    public var id: LocalizableId {
        "\(value.baseUnits) \(value.instance.id) \(unit.name) \(fractionDigits) \(showsSymbol)"
    }

    // MARK: Equatable, Hashable, Comparable

    /// One amount shown one way, whether or not it is localized yet
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the ``id``
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// By the amount
    ///
    /// - Precondition: both amounts are of one instance
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case value
        case unit
        case fractionDigits
        case showsSymbol
        case unitExponent
        case symbol
        case localizedString
    }

    /// Decodes with no registry: the unit's place and the symbol travel with the value
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            value: try container.decode(Amount.self, forKey: .value),
            unit: try container.decode(Asset.Unit.self, forKey: .unit),
            fractionDigits: try container.decode(Int.self, forKey: .fractionDigits),
            showsSymbol: try container.decode(Bool.self, forKey: .showsSymbol),
            unitExponent: try container.decode(Int.self, forKey: .unitExponent),
            symbol: try container.decode(String.self, forKey: .symbol),
            text: try container.decode(String.self, forKey: .localizedString)
        )
    }

    /// Carries the localized text: the text already bound, or the localizing encoder's
    ///
    /// - Throws: ``LocalizerError/localizationStoreMissing`` when a value not yet localized is encoded by an encoder
    ///   that does not localize
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encode(fractionDigits, forKey: .fractionDigits)
        try container.encode(showsSymbol, forKey: .showsSymbol)
        try container.encode(unitExponent, forKey: .unitExponent)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(text ?? encoder.localizeString(self) ?? "", forKey: .localizedString)
    }
}

// MARK: Stubs

extension LocalizableAmount {
    /// The stub amount in the stub unit, localized in `en_US`
    public static func stub() -> Self {
        .stub(value: .stub())
    }

    /// A stub with no registry: `unit` is read as if the amount's instance were its asset's home, and the text is
    /// bound in `en_US`
    public static func stub(value: Amount = .stub(), unit: Asset.Unit = .stub(), fractionDigits: Int? = nil,
                            showsSymbol: Bool = true) -> Self {
        let pending = Self(
            value: value,
            unit: unit,
            fractionDigits: fractionDigits ?? unit.fractionDigits ?? unit.exponent,
            showsSymbol: showsSymbol,
            unitExponent: unit.exponent,
            symbol: unit.symbol ?? unit.name,
            text: nil
        )
        return Self(
            value: pending.value,
            unit: pending.unit,
            fractionDigits: pending.fractionDigits,
            showsSymbol: pending.showsSymbol,
            unitExponent: pending.unitExponent,
            symbol: pending.symbol,
            text: pending.rendered(in: Locale(identifier: "en_US"))
        )
    }
}
