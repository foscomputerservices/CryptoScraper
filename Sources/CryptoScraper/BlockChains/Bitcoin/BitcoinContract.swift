// BitcoinContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct BitcoinContract: CryptoContract {
    public enum Unit {
        case satoshi
        case btc

        public var chainBaseUnit: Unit { .satoshi }
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public let chain: CryptoChain
    public var isChainToken: Bool {
        address == BitcoinChain.btcContractAddress
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

    /// Initializes the ``BitcoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.init(address: address, chain: .bitcoin)
    }

    init(address: String, chain: BitcoinChain) {
        self.address = address
        self.chain = chain
    }
}

private extension BitcoinContract.Unit {
    var divisorFromBase: UInt128 {
        let exponent: Double

        switch self {
        case .satoshi: exponent = 1
        case .btc: exponent = 8
        }

        return UInt128(pow(10, exponent))
    }
}
