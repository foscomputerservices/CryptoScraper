// BitcoinContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct BitcoinContract: CryptoContract, Codable, Stubbable {
    public enum Units: CurrencyUnits {
        case satoshi
        case btc

        public static var chainBaseUnits: Self { .satoshi }
        public static var defaultDisplayUnits: Self { .btc }
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: BitcoinChain { Chain.default }
    public var isChainToken: Bool {
        address == BitcoinChain.btcContractAddress
    }

    /// Initializes the ``BitcoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address // Case sensitive for BTC
    }
}

public extension BitcoinContract {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.address = try container.decode(String.self, forKey: .address)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(address, forKey: .address)
    }

    private enum CodingKeys: String, CodingKey {
        case address
    }
}

public extension BitcoinContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension BitcoinContract.Units {
    var divisorFromBase: UInt128 {
        let exponent: Double

        switch self {
        case .satoshi: exponent = 0
        case .btc: exponent = 8
        }

        return UInt128(pow(10, exponent))
    }

    var displayIdentifier: String {
        switch self {
        case .satoshi: return "SAT"
        case .btc: return "BTC"
        }
    }

    var displayFractionDigits: Int {
        switch self {
        case .satoshi: return 0
        case .btc: return 8
        }
    }
}
