// Amount.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// Represents a quantity of value in a ``Currency``'s base units
public struct Amount<C: Currency>: Hashable, Comparable, Codable {
    /// The quantity of the coin in the ``Currency``'s base units
    public let quantity: Int128

    /// The ``Currency`` that defines units for the *quantity*
    public let currency: C

    /// An internal optimization for .value(units: .defaultDisplayUnits)
    private let value: Double

    /// Returns the value of ``Amount`` in the given units
    ///
    /// - NOTE: The result should be used for summary purposes only and **never**
    ///  for calculations as ``Doubles`` have rounding errors and are not precise.  Perform
    ///  **all** calculations using the ``Amount``'s *chainBaseUnits*.
    ///
    /// - Parameter units: The ``CurrencyUnits`` in which to show the ``Amount``'s
    ///    *quantity*
    public func value(units: C.Units = .defaultDisplayUnits) -> Double {
        if units == .defaultDisplayUnits {
            return value
        } else {
            return currency.value(of: quantity, in: units)
        }
    }

    /// Returns a ``String`` representation of ``Amount`` in the given ``CurrencyUnits``
    ///
    /// The resulting representation uses ``CurrencyFormatter`` to format the ``Amount``
    ///
    /// - Parameter units: The ``CurrencyUnits`` in which to display ``Amount``
    ///    (default: *defaultDisplayUnits*)
    public func display(units: C.Units = .defaultDisplayUnits) -> String {
        currency.display(quantity: quantity, in: units)
    }

    // MARK: Codable Protocol

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.quantity = try container.decode(Int128.self, forKey: CodingKeys.quantity)
        self.currency = try container.decode(C.self, forKey: CodingKeys.currency)
        self.value = currency.value(of: self.quantity, in: .defaultDisplayUnits)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = try encoder.container(keyedBy: CodingKeys.self)

        try container.encode(quantity, forKey: .quantity)
        try container.encode(currency, forKey: .currency)
    }

    private enum CodingKeys: String, CodingKey {
        case quantity
        case currency
    }

    // MARK: Equatable Protocol

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.quantity == rhs.quantity && lhs.currency == rhs.currency
    }

    // MARK: Comparable Protocol

    public static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.currency == rhs.currency else {
            return false
        }

        return lhs.quantity < rhs.quantity
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        return .init(quantity: lhs.quantity + rhs.quantity, currency: lhs.currency)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        return .init(quantity: lhs.quantity - rhs.quantity, currency: lhs.currency)
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        return .init(quantity: lhs.quantity * rhs.quantity, currency: lhs.currency)
    }

    public static func / (lhs: Self, rhs: Self) -> Self {
        return .init(quantity: lhs.quantity / rhs.quantity, currency: lhs.currency)
    }

    /// Initializes ``Amount`` using a *quantity* in the ``Currency``'s *chainBaseUnits*
    ///
    /// - Parameters:
    ///   - quantity: The amount of the given ``Currency`` in **chainBaseUnits**
    ///   - currency: The ``Currency`` that *quantity* is valued in
    public init(quantity: Int128, currency: C) {
        self.quantity = quantity
        self.currency = currency
        self.value = currency.value(of: quantity, in: .defaultDisplayUnits)
    }

    /// Initializes ``Amount`` using a *quantity* in the ``Currency``'s ``Units``
    ///
    /// - NOTE: This initializer is not recommend for precise amounts as ``Double`` values
    ///   can have rounding errors.  It is recommended to use ``init(quantity:currency:)``
    ///   instead.
    ///
    /// - Parameters:
    ///   - quantity: The amount of the given ``Currency`` in ``Units``
    ///   - currency: The ``Currency`` that *quantity* is valued in
    ///   - units: The ``CurrencyUnits`` that *quantity* is specified in
    public init(quantity: Double, currency: C, units: C.Units) {
        self.quantity = currency.baseUnitsValue(of: quantity, in: units)
        self.currency = currency
        self.value = currency.value(of: self.quantity, in: .defaultDisplayUnits)
    }
}

public extension Amount where C: CryptoContract {
    /// Returns the ``CryptoContract`` of the amount
    ///
    /// - NOTE: This is simply an alias for *currency*
    var contract: C {
        currency
    }

    static var zero: Amount {
        .init(quantity: 0, currency: C.Chain.default.mainContract)
    }
}

extension Amount: Stubbable {
    public static func stub() -> Self {
        .init(
            quantity: 42,
            currency: .stub()
        )
    }
}
