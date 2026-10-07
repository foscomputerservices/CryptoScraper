// FiatCurrency.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// A government-issued store of value
public protocol FiatCurrency: Currency {

    /// A well-known representation of the currency (e.g. "usd")
    var symbol: String { get }
}

// MARK: The bridge (design § 1.4, § 1.5)

public extension AssetInstance {
    /// The instance `fiat` names: its ISO 4217 code in the `iso4217` namespace
    ///
    /// ```swift
    /// AssetInstance(USD()).id        // "iso4217:USD"
    /// ```
    ///
    /// - Precondition: the fiat's ``FiatCurrency/symbol``, upper-cased, is a three-letter ISO 4217 code.
    init(_ fiat: some FiatCurrency) {
        let id = ISO4217.namespace + ":" + fiat.symbol.uppercased()
        do {
            try self.init(validating: id)
        } catch {
            preconditionFailure("A fiat's symbol is not an ISO 4217 code: \(fiat.symbol)")
        }
    }
}
