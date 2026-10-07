// AmountError.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// The boundary rule: an instance is checked where a value enters the process (a validating decode, the clients'
// decode of an exchange's text, a DataModel's validation, a driver's read). Inside, two instances where one was
// required is a programmer error and the operators trap with a precondition; `adding(_:)` and `subtracting(_:)`
// on Amount are the throwing pair for the boundary itself. `==` is the one exemption, total for `Hashable`.
//
// `malformedText` and `belowBaseUnit` are thrown by the public clients' decode of number text, never by this
// library, which has no initializer from a string.

/// Why an amount, a fraction or a price could not be made, combined or converted
///
/// ```swift
/// do { _ = try ledgerBalance.adding(exchangeBalance) }
/// catch AmountError.instanceConflict(let ours, let theirs) { … }
/// ```
public enum AmountError: Error, Hashable, Sendable {
    /// Two values of different instances were combined where one instance was required
    case instanceConflict(AssetInstance, AssetInstance)
    /// A conversion between two instances the map does not put in one asset
    case notEquivalent(AssetInstance, AssetInstance)
    /// A conversion the target instance cannot hold exactly
    case notRepresentable(Amount, in: AssetInstance)
    /// Text that is not a number: letters, two points, a separator, an exponent
    case malformedText(String)
    /// Text with more fraction digits than the instance's base unit can hold
    case belowBaseUnit(String, decimals: Int)
}

// The trap for two instances where one was required, one wording for every operation.
func requireOneInstance(_ lhs: AssetInstance, _ rhs: AssetInstance, _ operation: StaticString,
                        file: StaticString = #fileID, line: UInt = #line) {
    precondition(
        lhs == rhs,
        "\(operation): instance conflict, \(lhs.id) against \(rhs.id)",
        file: file,
        line: line
    )
}
