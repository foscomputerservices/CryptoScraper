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
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        EthereumContract(address: address)
    }

    static let ethContractAddress = "ETH"

    public static let `default`: EthereumChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = Self.configuredScanners

        self.mainContract = EthereumContract(address: Self.ethContractAddress, chain: self)
    }

    private static var configuredScanners: [CryptoScanner] {
        var result = [CryptoScanner]()

        if Etherscan.serviceConfigured { result.append(Etherscan()) }

        return result
    }
}

public extension CryptoChain where Self == EthereumChain {
    static var ethereum: EthereumChain { .default }
}
