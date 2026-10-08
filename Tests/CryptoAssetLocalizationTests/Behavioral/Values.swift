import Foundation
import CryptoAsset
import FOSMVVM
import CryptoAssetLocalization

/// Every value the behavioral tests need. Each line marked `// INVENTED:` is a constructor or helper the design does not name;
/// the builder maps it onto the real member. No id of a real chain or exchange appears: every instance is a stub with a made-up symbol.
enum Fixture {
    static let enUS = Locale(identifier: "en_US")
    static let deDE = Locale(identifier: "de_DE")

    // MARK: instances

    /// 2 decimals, display unit with the sign "$", asset symbol "TKU" (so a test can tell the sign from the symbol)
    static func dollar() -> AssetInstance { AssetInstance.stub(symbol: "TKU", decimals: 2, displayUnit: Asset.Unit.stub(sign: "$", decimals: 2)) } // INVENTED:
    /// 8 decimals, NO unit names: the display unit is the asset's symbol "TKA"
    static func eightDecimals() -> AssetInstance { AssetInstance.stub(symbol: "TKA", decimals: 8, displayUnit: nil) } // INVENTED:
    /// 18 decimals, NO unit names: symbol "TKB"
    static func eighteenDecimals() -> AssetInstance { AssetInstance.stub(symbol: "TKB", decimals: 18, displayUnit: nil) } // INVENTED:
    /// A unit named "satoshi" worth exactly one base unit (0 fraction digits), for the 8-decimal instance
    static func satoshi() -> Asset.Unit { Asset.Unit.stub(sign: "satoshi", decimals: 0) } // INVENTED:

    // MARK: amounts, prices, fractions

    static func amount(_ baseUnits: Int, of instance: AssetInstance) -> Amount { Amount(baseUnits: baseUnits, instance: instance) }
    /// For counts a 64-bit integer cannot hold (10^24): the base units as decimal digits
    static func amount(digits: String, of instance: AssetInstance) -> Amount { Amount(baseUnitsDecimalString: digits, instance: instance) } // INVENTED:
    /// The quote per ONE WHOLE base unit, as plain decimal text ("65000.00", "0.123456789"), quote and base named
    static func price(_ decimal: String, quote: AssetInstance, base: AssetInstance) -> Price { Price(perWholeBase: decimal, quote: quote, base: base) } // INVENTED:
    static func fraction(basisPoints: Int) -> Fraction { Fraction(basisPoints: basisPoints) }

    // MARK: FOSMVVM

    static func store() -> LocalizationStore { LocalizationStore.empty() } // INVENTED:

    static func text(_ value: some Localizable, _ locale: Locale) throws -> String? { try value.localized(in: locale, store: store()) }

    /// The locale's own minus sign, as the number formatter of that locale writes it
    static func minus(_ locale: Locale) -> String { let f = NumberFormatter(); f.locale = locale; return f.minusSign } // INVENTED:

    static func localizedRoundTrip<T: Codable>(_ value: T, locale: Locale) throws -> (data: Data, decoded: T) { // INVENTED: shape of the encoder/decoder pair
        let encoder = JSONEncoder.localizingEncoder(in: locale, store: store(), strictLocalization: false)
        let data = try encoder.encode(value)
        return (data, try JSONDecoder().decode(T.self, from: data))
    }

    static func plainRoundTrip<T: Codable>(_ value: T) throws -> (data: Data, decoded: T) {
        let data = try JSONEncoder().encode(value)
        return (data, try JSONDecoder().decode(T.self, from: data))
    }

    /// Every string value anywhere in a JSON document (so a "/" escaped as "\/" never matters)
    static func strings(in data: Data) throws -> [String] {
        func walk(_ node: Any) -> [String] {
            if let s = node as? String { return [s] }
            if let a = node as? [Any] { return a.flatMap(walk) }
            if let d = node as? [String: Any] { return d.values.flatMap(walk) }
            return []
        }
        return walk(try JSONSerialization.jsonObject(with: data))
    }
}

/// A ViewModel-shaped value carrying the three types (the `@ViewModel` macro is not assumed)
struct Carrier: Codable, Hashable, Sendable { // INVENTED:
    let balance: LocalizableAmount
    let mid: LocalizablePrice
    let gain: LocalizableFraction
}
