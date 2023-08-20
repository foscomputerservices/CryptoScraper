// ZeroAmountContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct ZeroAmountContract: CryptoContract {
    public enum Units: CurrencyUnits {
        case none

        public static var chainBaseUnits: Self { .none }
        public static var defaultDisplayUnits: Self { .none }
    }

    public let address: String
    public let isChainToken: Bool
    public let isToken: Bool
    public let chain: ZeroAmountChain

    public static var zero: Self { .init(address: "") }

    // MARK: CurrencyFormatter

    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "<Z>"

        return numberFormatter
    }

    // MARK: Initialization Methods

    public init(address: String) {
        self.address = "0x0000000000000000000000000000000000000000"
        self.isChainToken = true
        self.isToken = false
        self.chain = ZeroAmountChain()
    }

    public init(from decoder: Decoder) throws {
        self = .zero
    }

    public func encode(to encoder: Encoder) throws {
        // N/A
    }
}

public extension ZeroAmountContract.Units {
    var divisorFromBase: UInt128 { 1 }

    var displayIdentifier: String {
        ""
    }

    var displayFractionDigits: Int { 0 }
}

extension ZeroAmountContract: Stubbable {
    public static func stub() -> Self {
        .zero
    }
}
