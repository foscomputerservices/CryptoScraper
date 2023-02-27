// TronChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class TronChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Tron"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        chainCryptos = coins.filter { coin in
            coin.contractAddress.chain.userReadableName == userReadableName
        }
    }

    public func contract(for address: String) throws -> CryptoContract {
        TronContract(address: address)
    }

    static let trxContractAddress = "TRX"

    public static let `default`: TronChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = Self.configuredScanners

        let mainContract = TronContract(address: Self.trxContractAddress, chain: self)
        self.mainContract = mainContract
        self.chainCryptos = [TRXCryptoInfo(contractAddress: mainContract)]
    }

    private static var configuredScanners: [CryptoScanner] {
        [TronScan()]
    }
}

public extension CryptoChain where Self == TronChain {
    static var tron: TronChain { .default }
}

private struct TRXCryptoInfo: CryptoInfo {
    let contractAddress: CryptoContract

    let tokenName: String = "Tron"
    let symbol: String = "TRX"
    let whitepaper: URL? = URL(string: "https://tron.network/static/doc/white_paper_v_2_0.pdf")!
}
