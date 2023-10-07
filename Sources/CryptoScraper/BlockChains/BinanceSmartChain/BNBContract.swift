// BNBContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct BNBContract: CryptoContract, Stubbable {
    // MARK: CurrencyFormatter

    public typealias Units = EthereumContract.Units

    // MARK: CryptoContract Protocol

    public typealias Chain = BinanceSmartChain

    public let address: String

    /// Initializes the ``BNBContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension BNBContract {
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

public extension BNBContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}
