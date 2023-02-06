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

    public init() {
        self.chainContracts = []
        self.scanners = [
            Etherscan()
        ]

        self.mainContract = EthereumContract(address: "ETH", chain: self)
        self.chainContracts = [
            EthereumContract(address: "ETH", chain: self)
        ]
    }
}

public extension CryptoChain where Self == EthereumChain {
    static var ethereum: EthereumChain { .init() }
}
