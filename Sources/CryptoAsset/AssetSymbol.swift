// AssetSymbol.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// The symbol of an asset, as the exchange or the universe gave it: "BTC", "USDC", "USD"
///
/// A symbol is validated on the way in, upper-cased, so a malformed one is an error at the boundary and never a
/// value inside; decoding validates the same way, so a malformed symbol in a stored value is a `DecodingError`.
///
/// ```swift
/// let btc = try AssetSymbol(validating: "btc")      // "BTC"
/// let request = "\(btc.text)USDT"                    // the text, for an exchange's request or a label
/// ```
public struct AssetSymbol: Codable, Hashable, Sendable, Stubbable {
    /// The symbol's text, upper-cased
    public let text: String

    /// - Throws: ``AssetSymbolError`` when `candidate` is empty, longer than twelve characters, or carries a
    ///   character other than a letter, a digit, a point or a dash
    public init(validating candidate: String) throws {
        self.text = try Self.normalized(candidate)
    }

    // The one place the rule for a well-formed symbol lives (OQ-C2: letters, digits, point and dash, one to
    // twelve characters, upper-cased on the way in). The day the normalization must be pluggable, this changes.
    //
    // "A letter" is read as an ASCII letter, A through Z after upper-casing: a symbol is sent back to exchanges
    // inside their requests, and a non-ASCII letter would upper-case differently by locale and by Unicode version.
    private static func normalized(_ candidate: String) throws -> String {
        guard !candidate.isEmpty else {
            throw AssetSymbolError.empty
        }
        guard candidate.count <= 12 else {
            throw AssetSymbolError.malformed(candidate)
        }

        let upper = candidate.uppercased()
        let wellFormed = upper.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "0"..."9", ".", "-": true
            default: false
            }
        }
        guard wellFormed, upper.count == candidate.count else {
            throw AssetSymbolError.malformed(candidate)
        }

        return upper
    }

    // MARK: Codable

    // A symbol encodes as its text alone and decodes through the validating initializer, so a malformed symbol in
    // a stored value is a DecodingError and never a value inside.

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        do {
            self.text = try Self.normalized(candidate)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a well-formed asset symbol: \"\(candidate)\" (\(error))"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// Why a string is not a symbol
///
/// ```swift
/// do { _ = try AssetSymbol(validating: "") } catch AssetSymbolError.empty { … }
/// ```
public enum AssetSymbolError: Error, Hashable, Sendable {
    case empty
    case malformed(String)
}
