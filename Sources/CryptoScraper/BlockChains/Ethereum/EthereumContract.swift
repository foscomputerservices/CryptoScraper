// EthereumContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct EthereumContract: CryptoContract {
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
    public let chain: CryptoChain
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
    public func displayAmount(amount: Int64, inUnits: Unit) -> Double {
        Double(amount) / Double(inUnits.divisorFromBase)
    }

    /// Initializes the ``EthereumContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.init(address: address, chain: .ethereum)
    }

    init(address: String, chain: EthereumChain) {
        self.address = address
        self.chain = chain
    }
}

private extension EthereumContract.Unit {
    var divisorFromBase: Int64 {
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

        return Int64(pow(10, exponent))
    }
}
