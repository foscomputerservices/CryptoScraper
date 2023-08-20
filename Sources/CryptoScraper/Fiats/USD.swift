// USD.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct USD: FiatCurrency {
    // MARK: FiatCurrency Protocol

    public enum Units: CurrencyUnits {
        case cents
        case dollars

        public static var chainBaseUnits: Self { .cents }
        public static var defaultDisplayUnits: Self { .dollars }
    }
}

public extension USD.Units {
    var divisorFromBase: UInt128 {
        let exponent: Double
        switch self {
        case .cents: exponent = 1
        case .dollars: exponent = 10
        }

        return UInt128(pow(10, exponent))
    }

    var displayIdentifier: String {
        switch self {
        case .cents: return "¢"
        case .dollars: return "$"
        }
    }

    var displayFractionDigits: Int {
        switch self {
        case .cents: return 0
        case .dollars: return 2
        }
    }
}

extension USD: Stubbable {
    public static func stub() -> Self {
        .init()
    }
}
