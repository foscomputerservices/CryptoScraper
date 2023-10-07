// OptimismContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct OptimismContract: CryptoContract, Codable, Stubbable {
    public typealias Units = EthereumContract.Units

    // MARK: CurrencyFormatter

    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "OP"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = OptimismChain

    public let address: String

    /// Initializes the ``OptimismContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension OptimismContract {
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

public extension OptimismContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}
