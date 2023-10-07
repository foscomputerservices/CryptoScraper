// TronContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct TronContract: CryptoContract, Codable, Stubbable {
    // https://developers.tron.network/docs/token-standards-trx#denominations-of-trx
    public enum Units: String, CurrencyUnits {
        case sun
        case trx

        public static var chainBaseUnits: Self { .sun }
        public static var defaultDisplayUnits: Self { .trx }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = TronChain

    public let address: String

    /// Initializes the ``TronContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension TronContract {
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

public extension TronContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension TronContract.Units {
    var divisorFromBase: UInt128 {
        let exponent: Double

        switch self {
        case .sun: exponent = 1
        case .trx: exponent = 6
        }

        return UInt128(pow(10, exponent))
    }

    var displayIdentifier: String {
        self == .trx
            ? "TRX"
            : "TRX(\(rawValue))"
    }

    var displayFractionDigits: Int {
        switch self {
        case .sun: return 0
        case .trx: return 6
        }
    }
}
