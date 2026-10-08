// LocalizablePrice.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import FOSMVVM
import Foundation

// The design's C11 (docs/fosline-suite-protocols.md § 2), on 0.6.1's Price: a price is `{quote, base, scaled}`,
// `scaled` being quote base units per whole base unit times 10^9, and carries no decimals. The quote's display unit,
// its place on the quote instance and the two symbols are read from the registry when the value is made and carried
// with it.

/// A ``Price`` for a reader: the quote per one whole base unit as ``LocalizableAmount`` renders it, the pair after it
///
/// A price is two assets, so it is not an amount and ``LocalizableAmount`` cannot render it: the quote's sign and
/// the base's symbol both appear, and a sub-unit price has digits no amount of the quote has.
///
/// ```swift
/// public let mid: LocalizablePrice                 // "65,000.00 $ / BTC"
/// try LocalizablePrice(mid, fractionDigits: 2)
/// ```
///
/// The number is in the quote asset's display unit, grouped by the locale's separator, with the locale's point, cut
/// toward zero to ``fractionDigits``; no `Double` is formed. Unless fewer are asked for, every digit the price holds
/// is shown: the display unit's own digits and the nine below one quote base unit.
public struct LocalizablePrice: LocalizableValue, Comparable {
    /// The exact price
    public let value: Price
    /// How many fraction digits the reader sees, at most the display unit's exponent on the quote instance plus nine
    public let fractionDigits: Int

    // The power of ten of the quote instance's base units in one of the quote's display unit; the text after the
    // number: the display unit's sign or the quote asset's symbol, and the base asset's symbol.
    private let quoteExponent: Int
    private let quoteSymbol: String
    private let baseSymbol: String
    private let text: String?

    // A price's scale: quote base units per whole base unit, times 10^9.
    private static let scaleDigits = 9

    /// A price for a reader, in the quote asset's display unit
    ///
    /// - Parameters:
    ///   - value: The exact price
    ///   - fractionDigits: How many fraction digits the reader sees; `nil` for every digit the price holds
    ///   - registry: The statement the two instances, their assets and the quote's display unit are read from
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when the quote or the base is not declared;
    ///   ``AssetError/unitOutOfRange(_:)`` when the quote's display unit is finer than the quote instance's base unit
    public init(_ value: Price, fractionDigits: Int? = nil, in registry: AssetRegistry = .shared) throws {
        let quote = try registry.declaration(of: registry.asset(of: value.quote))
        let base = try registry.declaration(of: registry.asset(of: value.base))
        let quoteExponent = try exponent(of: quote.displayUnit, on: value.quote, in: registry)
        self.init(
            value: value,
            fractionDigits: fractionDigits ?? quoteExponent + Self.scaleDigits,
            quoteExponent: quoteExponent,
            quoteSymbol: symbolText(of: quote.displayUnit, in: quote),
            baseSymbol: base.symbol.text,
            text: nil
        )
    }

    private init(value: Price, fractionDigits: Int, quoteExponent: Int, quoteSymbol: String, baseSymbol: String,
                 text: String?) {
        self.value = value
        self.fractionDigits = min(max(fractionDigits, 0), quoteExponent + Self.scaleDigits)
        self.quoteExponent = quoteExponent
        self.quoteSymbol = quoteSymbol
        self.baseSymbol = baseSymbol
        self.text = text
    }

    /// The price's text in `locale`: the number in the quote's display unit, its sign, then " / " and the base's
    /// symbol
    ///
    /// Needs nothing from `store`: the separators and signs are the locale's, the symbols the declarations'.
    public func localized(in locale: Locale, store: LocalizationStore) throws -> String? {
        rendered(in: locale)
    }

    private func rendered(in locale: Locale) -> String {
        let number = LocaleDigits(locale).number(
            digits: value.scaled.magnitudeDigits,
            scale: quoteExponent + Self.scaleDigits,
            fractionDigits: fractionDigits,
            negative: value.scaled < 0
        )
        return number + " " + quoteSymbol + " / " + baseSymbol
    }

    // MARK: Localizable

    /// Never empty: a price always has a number
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

    /// The value and how it is shown: its quote, its base, its scaled number and the fraction digits
    public var id: LocalizableId {
        "\(value.scaled) \(value.quote.id) / \(value.base.id) \(fractionDigits)"
    }

    // MARK: Equatable, Hashable, Comparable

    /// One price shown one way, whether or not it is localized yet
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the ``id``
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// By the price
    ///
    /// - Precondition: both prices share a base and a quote instance
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case value
        case fractionDigits
        case quoteExponent
        case quoteSymbol
        case baseSymbol
        case localizedString
    }

    /// Decodes with no registry: the quote's place and the symbols travel with the value
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            value: try container.decode(Price.self, forKey: .value),
            fractionDigits: try container.decode(Int.self, forKey: .fractionDigits),
            quoteExponent: try container.decode(Int.self, forKey: .quoteExponent),
            quoteSymbol: try container.decode(String.self, forKey: .quoteSymbol),
            baseSymbol: try container.decode(String.self, forKey: .baseSymbol),
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
        try container.encode(fractionDigits, forKey: .fractionDigits)
        try container.encode(quoteExponent, forKey: .quoteExponent)
        try container.encode(quoteSymbol, forKey: .quoteSymbol)
        try container.encode(baseSymbol, forKey: .baseSymbol)
        try container.encode(text ?? encoder.localizeString(self) ?? "", forKey: .localizedString)
    }
}

// MARK: Stubs

extension LocalizablePrice {
    /// The stub price, localized in `en_US`
    public static func stub() -> Self {
        .stub(value: .stub())
    }

    /// A stub with no registry: the quote read at its base unit, both symbols the stub symbol's text, and the text
    /// bound in `en_US`
    public static func stub(value: Price = .stub(), fractionDigits: Int = 2) -> Self {
        let pending = Self(
            value: value,
            fractionDigits: fractionDigits,
            quoteExponent: 0,
            quoteSymbol: AssetSymbol.stub().text,
            baseSymbol: AssetSymbol.stub().text,
            text: nil
        )
        return Self(
            value: pending.value,
            fractionDigits: pending.fractionDigits,
            quoteExponent: pending.quoteExponent,
            quoteSymbol: pending.quoteSymbol,
            baseSymbol: pending.baseSymbol,
            text: pending.rendered(in: Locale(identifier: "en_US"))
        )
    }
}
