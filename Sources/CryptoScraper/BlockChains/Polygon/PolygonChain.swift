// PolygonChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class PolygonChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Matic"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        MaticContract(address: address)
    }

    static let maticContractAddress = "Matic"

    public static let `default`: PolygonChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = Self.configuredScanners

        self.mainContract = MaticContract(address: Self.maticContractAddress, chain: self)
    }

    private static var configuredScanners: [CryptoScanner] {
        var result = [CryptoScanner]()

        if PolygonScan.serviceConfigured { result.append(PolygonScan()) }

        return result
    }
}

public extension CryptoChain where Self == PolygonChain {
    static var polygon: PolygonChain { .default }
}
