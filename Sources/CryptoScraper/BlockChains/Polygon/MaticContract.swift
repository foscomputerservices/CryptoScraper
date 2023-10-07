// MaticContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct MaticContract: CryptoContract, Codable, Stubbable {
    public typealias Units = EthereumContract.Units

    // MARK: CurrencyFormatter

    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "Matic"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = PolygonChain

    public let address: String

    /// Initializes the ``MaticContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension MaticContract {
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

public extension MaticContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}
