// BinanceSmartChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class BinanceSmartChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "BNB"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        BNBContract(address: address)
    }

    static let bnbContractAddress = "BNB"

    public static let `default`: BinanceSmartChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = [
            BscScan()
        ]

        self.mainContract = BNBContract(address: Self.bnbContractAddress, chain: self)
    }
}

public extension CryptoChain where Self == BinanceSmartChain {
    static var binance: BinanceSmartChain { .default }
}
