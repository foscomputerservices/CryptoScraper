// ThetaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Theta: an EVM address, lower-cased, counted in Ethereum's ladder, as ``OptimismContract`` is
public struct ThetaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Ethereum's ladder: wei to tether, ether, the chain's coin, at 18 decimals; its display identifier is
    /// Ethereum's, `ETH`, not TFUEL
    public typealias Units = EthereumContract.Units

    // MARK: CurrencyFormatter

    /// A currency formatter in TFUEL
    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "TFUEL"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = ThetaChain

    /// The contract's address, lower-cased
    public let address: String

    /// Initializes the ``ThetaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension ThetaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension ThetaContract {
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
