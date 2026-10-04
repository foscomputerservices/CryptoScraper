// FiatCurrency.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A government-issued store of value
public protocol FiatCurrency: Currency {

    /// A well-known representation of the currency (e.g. "usd")
    var symbol: String { get }
}
