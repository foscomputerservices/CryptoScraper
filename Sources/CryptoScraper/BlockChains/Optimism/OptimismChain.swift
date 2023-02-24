// OptimismChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class OptimismChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Optimism"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        OptimismContract(address: address)
    }

    static let opContractAddress = "OP"

    public static let `default`: OptimismChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = Self.configuredScanners

        self.mainContract = OptimismContract(address: Self.opContractAddress, chain: self)
    }

    private static var configuredScanners: [CryptoScanner] {
        var result = [CryptoScanner]()

        if OptimisticEtherscan.serviceConfigured { result.append(OptimisticEtherscan()) }

        return result
    }
}

public extension CryptoChain where Self == OptimismChain {
    static var optimism: OptimismChain { .default }
}
