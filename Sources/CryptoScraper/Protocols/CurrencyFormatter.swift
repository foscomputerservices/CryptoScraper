// CurrencyFormatter.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A mechanism for formatting a currency value
public protocol CurrencyFormatter {
    associatedtype Units: CurrencyUnits

    /// Returns a ``Double`` converted from *chainBaseUnits* to *units*
    ///
    /// - NOTE: The resulting value is for **display purposes only**; no
    ///      calculations should be done using the result as all calculations
    ///      should be performed in the chain's base units so that no
    ///      rounding errors occur.
    ///
    /// - Parameters:
    ///   - quantity: The quantity, in **chainBaseUnits** to convert to *units*
    ///   - units: The ``CurrencyUnits`` to display *quantity* in
    func value(of quantity: UInt128, in units: Units) -> Double

    /// Returns the ``UInt128`` value in *chainBaseUnits* converted from the given *quantity*
    ///
    /// - NOTE: This conversion should be used sparingly as it uses conversion from **double**,
    ///     which can have rounding problems.
    ///
    /// - Parameters:
    ///   - quantity: The quantity, in *units*
    ///   - units: The ``Units`` that *quantity* is represented in
    func baseUnitsValue(of quantity: Double, in units: Units) -> UInt128

    /// Returns a ``String`` that is a fully formatted representation of the given *quantity*
    ///
    /// - Parameters:
    ///   - quantity: The *quantity*, in **chainBaseUnits** to display
    ///   - units: The ``CurrencyUnits`` to display *quantity* in
    func display(quantity: UInt128, in units: Units) -> String
}

/// A description of the value units for a ``Currency``
///
/// The following is an example for USD:
///
/// ```
///   public enum USDUnit: CurrencyUnits {
///     case cents
///     case dollars
///
///     public static var chainBaseUnits: Self { .cents }
///     public static var defaultDisplayUnits: Self { .dollars }
///
///     public var divisorFromBase: UInt128 {
///       let exponent: Double
///       switch self {
///       case .cents: exponent = 1
///       case .dollars: exponent = 10
///       }
///       return UInt128(pow(10, exponent))
///     }
///
///     public var displayIdentifier: String {
///       switch self {
///       case .cents: return "¢"
///       case .dollars: return "$"
///       }
///   }
/// ```
public protocol CurrencyUnits: Codable, Stubbable {
    /// The standard unit used by the ``CryptoChain`` to store values
    static var chainBaseUnits: Self { get }

    /// The default unit to display values to the user
    static var defaultDisplayUnits: Self { get }

    /// The value to divide a given number by to convert from this ``CurrencyUnits``
    /// to *chainBaseUnit*
    var divisorFromBase: UInt128 { get }

    /// A ``String`` to display to the user to identify a value of this ``CryptoChain``
    /// in the ``CurrencyUnits``
    var displayIdentifier: String { get }

    /// The number of digits to display in the fraction when displaying
    /// values in a ``Double``
    var displayFractionDigits: Int { get }
}

public extension CurrencyFormatter {
    func value(of quantity: UInt128, in units: Units) -> Double {
        units.value(of: quantity)
    }

    func baseUnitsValue(of quantity: Double, in units: Units) -> UInt128 {
        units.baseUnitsValue(of: quantity)
    }

    func display(quantity: UInt128, in units: Units) -> String {
        units.display(quantity: quantity)
    }
}

public extension CurrencyUnits {
    static func stub() -> Self {
        .defaultDisplayUnits
    }

    var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = displayIdentifier
        numberFormatter.minimumFractionDigits = displayFractionDigits
        numberFormatter.maximumFractionDigits = displayFractionDigits

        return numberFormatter
    }
}

private extension CurrencyUnits {
    /// Converts *quantity* to the given ``CurrencyUnits``
    ///
    /// - Parameter quantity: amount in currency in **chainBaseUnits**
    func value(of quantity: UInt128) -> Double {
        Double(quantity) / Double(divisorFromBase)
    }

    /// Converts *quantity* from the given ``CurrencyUnits`` to **chainBaseUnits**
    ///
    /// - Parameter quantity: amount of currency in ``CurrencyUnits``
    func baseUnitsValue(of quantity: Double) -> UInt128 {
        let unitsDivisorFromBaseUnits = divisorFromBase

        return UInt128(quantity * Double(unitsDivisorFromBaseUnits))
    }

    /// Creates a ``String`` representation of *quantity* converted to the given ``CurrencyUnits``
    ///
    /// - Parameter quantity: amount of currency in **chainBaseUnits**
    func display(quantity: UInt128) -> String {
        formatter.string(
            for: value(of: quantity)
        ) ?? "N/A"
    }
}
