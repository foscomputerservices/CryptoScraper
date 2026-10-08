// LocalizableFraction.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import FOSMVVM
import Foundation

// The design's C11 (docs/fosline-suite-protocols.md § 2), on 0.6.1's Fraction: its numerator at the scale 10^9 is
// sealed, vended by no property (§ 9.7 of the protocols), so this library reads it through Fraction's public algebra:
// 10^9 base units scaled by the fraction are, exactly, the numerator in base units (`Amount * Fraction` multiplies
// at full width and divides by 10^9, which leaves no remainder here). The instance the product is counted in is
// immaterial to the product; the dollar's is used.

/// A ``Fraction`` for a reader, in percentage points: "12.50 %", "+12.50 %", "-0.25 %"
///
/// ```swift
/// public let gain: LocalizableFraction             // "+12.50 %"
/// LocalizableFraction(gain, showsSign: true)
/// LocalizableFraction(step)                        // "0.25 %"
/// ```
///
/// The number is grouped by the locale's separator, with the locale's point and the locale's percent symbol, cut
/// toward zero to ``fractionDigits``; no `Double` is formed. A negative value always carries the locale's minus.
public struct LocalizableFraction: LocalizableValue, Comparable {
    /// The exact fraction
    public let value: Fraction
    /// How many fraction digits of a percentage point the reader sees: 0 through 7, the digits a fraction holds
    public let fractionDigits: Int
    /// Whether a positive value carries its sign, as a gain does and a slippage step does not
    public let showsSign: Bool

    private let text: String?

    // A fraction holds nine fraction digits of one; a percentage point is 10^-2 of one, so seven remain.
    private static let percentScale = 7

    /// A fraction for a reader, in percentage points
    ///
    /// - Parameters:
    ///   - value: The exact fraction
    ///   - fractionDigits: How many fraction digits of a percentage point the reader sees, 0 through 7
    ///   - showsSign: Whether a positive value carries its sign
    public init(_ value: Fraction, fractionDigits: Int = 2, showsSign: Bool = false) {
        self.init(value: value, fractionDigits: fractionDigits, showsSign: showsSign, text: nil)
    }

    private init(value: Fraction, fractionDigits: Int, showsSign: Bool, text: String?) {
        self.value = value
        self.fractionDigits = min(max(fractionDigits, 0), Self.percentScale)
        self.showsSign = showsSign
        self.text = text
    }

    /// The fraction's text in `locale`: the sign where one is shown, the number of percentage points, then the
    /// locale's percent symbol
    ///
    /// Needs nothing from `store`: the separators, signs and percent symbol are the locale's.
    public func localized(in locale: Locale, store: LocalizationStore) throws -> String? {
        rendered(in: locale)
    }

    private func rendered(in locale: Locale) -> String {
        let digits = LocaleDigits(locale)
        let numerator = Self.numerator(of: value)
        let number = digits.number(
            digits: numerator.magnitudeDigits,
            scale: Self.percentScale,
            fractionDigits: fractionDigits,
            negative: numerator < 0
        )
        let signed = showsSign && numerator > 0 ? digits.plusSign + number : number
        return signed + " " + digits.percentSymbol
    }

    // The sealed numerator at the scale 10^9, exactly, through the public algebra.
    private static func numerator(of fraction: Fraction) -> Int128 {
        (Amount(baseUnits: 1_000_000_000, of: ISO4217.usd.instance) * fraction).baseUnits
    }

    // MARK: Localizable

    /// Never empty: a fraction always has a number
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

    /// The value and how it is shown: its numerator, the fraction digits and the sign's presence
    public var id: LocalizableId {
        "\(Self.numerator(of: value)) \(fractionDigits) \(showsSign)"
    }

    // MARK: Equatable, Hashable, Comparable

    /// One fraction shown one way, whether or not it is localized yet
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the ``id``
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// By the fraction
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case value
        case fractionDigits
        case showsSign
        case localizedString
    }

    /// Decodes the value, how it is shown and its text
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            value: try container.decode(Fraction.self, forKey: .value),
            fractionDigits: try container.decode(Int.self, forKey: .fractionDigits),
            showsSign: try container.decode(Bool.self, forKey: .showsSign),
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
        try container.encode(showsSign, forKey: .showsSign)
        try container.encode(text ?? encoder.localizeString(self) ?? "", forKey: .localizedString)
    }
}

// MARK: Stubs

extension LocalizableFraction {
    /// The stub fraction, localized in `en_US`
    public static func stub() -> Self {
        .stub(value: .stub())
    }

    /// A stub whose text is bound in `en_US`
    public static func stub(value: Fraction = .stub(), fractionDigits: Int = 2, showsSign: Bool = false) -> Self {
        let pending = Self(value, fractionDigits: fractionDigits, showsSign: showsSign)
        return Self(
            value: pending.value,
            fractionDigits: pending.fractionDigits,
            showsSign: pending.showsSign,
            text: pending.rendered(in: Locale(identifier: "en_US"))
        )
    }
}
