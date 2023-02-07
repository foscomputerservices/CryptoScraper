// BNBContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct BNBContract: CryptoContract {
    // https://etherscan.io/unitconverter -- Cannot find a BscScan equivalent page 🤷‍♂️
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
        address == BinanceSmartChain.bnbContractAddress
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

    /// Initializes the ``BNBContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.init(address: address, chain: .binance)
    }

    init(address: String, chain: BinanceSmartChain) {
        self.address = address
        self.chain = chain
    }
}

private extension BNBContract.Unit {
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
