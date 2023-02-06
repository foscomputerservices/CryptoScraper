// EthereumChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct EthereumChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Ethereum"
    public let scanners: [CryptoScanner]
    public private(set) var chainContracts: [CryptoContract]
    public private(set) var mainContract: CryptoContract!

    static let ethContractAddress = "ETH"

    public init() {
        self.chainContracts = []
        self.scanners = [
            Etherscan()
        ]

        self.mainContract = EthereumContract(address: Self.ethContractAddress, chain: self)
        self.chainContracts = [
            EthereumContract(address: Self.ethContractAddress, chain: self)
        ]
    }
}

public extension CryptoChain where Self == EthereumChain {
    static var ethereum: EthereumChain { .init() }
}
