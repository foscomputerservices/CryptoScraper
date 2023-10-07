// TestCoinContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSFoundation
import Foundation

public struct TestCoinContract: CryptoContract {
    // MARK: CurrencyFormatter

    public typealias Chain = TestCoinChain
    public enum Units: CurrencyUnits {
        case unit

        public static var chainBaseUnits: TestCoinContract.Units { .unit }
        public static var defaultDisplayUnits: TestCoinContract.Units { .unit }
        public var divisorFromBase: Numberick.UInt128 { 1 }
        public var displayIdentifier: String { "Unit" }
        public var displayFractionDigits: Int { 0 }
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: TestCoinChain { TestCoinChain.default }
    public var isChainToken: Bool {
        address == TestCoinChain.tcContractAddress
    }

    public init(address: String) {
        self.address = address.lowercased()
    }
}

extension TestCoinContract: Stubbable {
    public static func stub() -> Self {
        .init(address: "<Test Address>")
    }
}
