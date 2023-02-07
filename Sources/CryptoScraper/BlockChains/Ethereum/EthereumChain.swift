// EthereumChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class EthereumChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Ethereum"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.address == mainContract!.address &&
                coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        EthereumContract(address: address)
    }

    static let ethContractAddress = "ETH"

    public init() {
        self.chainCryptos = []
        self.scanners = [
            Etherscan()
        ]

        self.mainContract = EthereumContract(address: Self.ethContractAddress, chain: self)
    }
}

public extension CryptoChain where Self == EthereumChain {
    static var ethereum: EthereumChain { .init() }
}
