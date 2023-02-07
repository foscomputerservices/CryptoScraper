// FantomChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class FantomChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Fantom"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        FantomContract(address: address)
    }

    static let ftmContractAddress = "FTM"

    public static let `default`: FantomChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = [
            FTMScan()
        ]

        self.mainContract = FantomContract(address: Self.ftmContractAddress, chain: self)
    }
}

public extension CryptoChain where Self == FantomChain {
    static var fantom: FantomChain { .default }
}
