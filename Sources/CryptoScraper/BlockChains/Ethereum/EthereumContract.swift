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

        public func convertDown(amount: UInt128, smallerUnits units: Unit) -> UInt128 {
            let currentExp = exponent
            let newExp = units.exponent

            guard newExp < currentExp else {
                fatalError("Cannot convert to larger units")
            }

            if newExp == currentExp {
                return amount
            }

            let exponent = UInt128(currentExp - newExp)
            let power = UInt128(pow(10, Double(exponent)))

            return amount * power
        }
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
        self.address = address.lowercased()
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
        UInt128(pow(10, Double(exponent)))
    }

    var exponent: Int {
        switch self {
        case .wei: return 1
        case .kwei: return 3
        case .mwei: return 6
        case .gwei: return 9
        case .szabo: return 12
        case .finney: return 15
        case .ether: return 18
        case .kether: return 21
        case .mether: return 24
        case .gether: return 27
        case .tether: return 30
        }
    }
}
