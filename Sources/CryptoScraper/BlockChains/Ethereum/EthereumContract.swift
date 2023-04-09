// EthereumContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct EthereumContract: CryptoContract, Codable, Stubbable {
    public typealias Chain = EthereumChain

    // https://etherscan.io/unitconverter
    public enum Unit {
        case wei
        case kwei
        case mwei
        case gwei
        case szabo
        case finney
        case ether
        case kether
        case mether
        case gether
        case tether

        public var chainBaseUnit: Unit { .wei }
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: Chain { Chain.default }
    public var isChainToken: Bool {
        address == EthereumChain.ethContractAddress
    }

    /// Converts a given amount for display in other chain units
    ///
    /// - NOTE: The resulting value is for **display purposes only**; no
    ///      calculations should be done using the result as all calculations
    ///      should be performed in the chain's base units so that no
    ///      rounding errors occur.
    ///
    /// - Parameters:
    ///   - amount: The amount in the chain's base unit
    ///   - inUnits: The units to display the amount in
    public func displayAmount(amount: UInt128, inUnits: Unit) -> Double {
        Double(amount) / Double(inUnits.divisorFromBase)
    }

    /// Initializes the ``EthereumContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension EthereumContract {
    // MARK: Codable Protocol

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

public extension EthereumContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

private extension EthereumContract.Unit {
    var divisorFromBase: UInt128 {
        let exponent: Double

        switch self {
        case .wei: exponent = 1
        case .kwei: exponent = 3
        case .mwei: exponent = 6
        case .gwei: exponent = 9
        case .szabo: exponent = 12
        case .finney: exponent = 15
        case .ether: exponent = 18
        case .kether: exponent = 21
        case .mether: exponent = 24
        case .gether: exponent = 27
        case .tether: exponent = 30
        }

        return UInt128(pow(10, exponent))
    }
}
