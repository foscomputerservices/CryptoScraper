// AmountError.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The boundary rule: an asset is checked where a value enters the process (a validating decode, the clients'
// decode of an exchange's text, a DataModel's validation, a driver's read). Inside, two assets where one was
// required is a programmer error and the operators trap with a precondition; `adding(_:)` and `subtracting(_:)`
// on Amount are the throwing pair for the boundary itself. `==` is the one exemption, total for `Hashable`.
//
// `malformedText` and `belowBaseUnit` are thrown by the public clients' decode of number text, never by this
// library, which has no initializer from a string.

/// Why an amount, a fraction or a price could not be made or combined
///
/// ```swift
/// do { _ = try ledgerBalance.adding(exchangeBalance) }
/// catch AmountError.assetConflict(let ours, let theirs) { … }
/// ```
public enum AmountError: Error, Hashable, Sendable {
    /// Two values of different assets were combined where one asset was required
    case assetConflict(AssetSymbol, AssetSymbol)
    /// Text that is not a number: letters, two points, a separator, an exponent
    case malformedText(String)
    /// Text with more fraction digits than the base unit can hold
    case belowBaseUnit(String, unitExponent: Int)
}

// The trap for two assets where one was required, one wording for every operation.
func requireOneAsset(_ lhs: Asset, _ rhs: Asset, _ operation: StaticString,
                     file: StaticString = #fileID, line: UInt = #line) {
    precondition(
        lhs == rhs,
        "\(operation): asset conflict, \(lhs.symbol.text) against \(rhs.symbol.text)",
        file: file,
        line: line
    )
}
