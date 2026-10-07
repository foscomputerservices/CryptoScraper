// EthereumClassicContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Ethereum Classic: an EVM address, lower-cased, counted in Ethereum's ladder, as ``OptimismContract`` is
public struct EthereumClassicContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Ethereum's ladder: wei to ether, the chain's coin at 18 decimals
    public typealias Units = EthereumContract.Units

    // MARK: CurrencyFormatter

    /// A currency formatter in ETC
    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "ETC"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = EthereumClassicChain

    /// The contract's address, lower-cased
    public let address: String

    /// Initializes the ``EthereumClassicContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension EthereumClassicContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension EthereumClassicContract {
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
