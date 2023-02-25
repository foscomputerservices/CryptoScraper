// BitcoinChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class BitcoinChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Bitcoin"
    public let scanners: [CryptoScanner]
    public private(set) var chainCryptos: [CryptoInfo]
    public private(set) var mainContract: CryptoContract!

    public func loadChainCryptos(from coins: [CryptoInfo]) {
        // This is a no-op for BTC, there's only one
    }

    public func contract(for address: String) throws -> CryptoContract {
        BitcoinContract(address: address)
    }

    static let btcContractAddress = "BTC"

    public static let `default`: BitcoinChain = .init()

    private init() {
        self.chainCryptos = []
        self.scanners = Self.configuredScanners

        let mainContract = BitcoinContract(address: Self.btcContractAddress, chain: self)
        self.mainContract = mainContract
        self.chainCryptos = [BTCCryptoInfo(contractAddress: mainContract)]
    }

    private static var configuredScanners: [CryptoScanner] {
        [BlockChainInfo()]
    }
}

public extension CryptoChain where Self == BitcoinChain {
    static var bitcoin: BitcoinChain { .default }
}

private struct BTCCryptoInfo: CryptoInfo {
    let contractAddress: CryptoContract

    let tokenName: String = "Bitcoin"
    let symbol: String = "BTC"
    let tokenType: String? = nil
    let totalSupply: CryptoAmount? = nil
    let blueCheckmark: Bool? = nil
    let description: String? = nil
    let website: URL? = nil
    let email: String? = nil
    let blog: URL? = nil
    let reddit: URL? = nil
    let slack: String? = nil
    let facebook: URL? = nil
    let twitter: URL? = nil
    let gitHub: URL? = nil
    let telegram: URL? = nil
    let wechat: URL? = nil
    let linkedin: URL? = nil
    let discord: URL? = nil
    let whitepaper: URL? = URL(string: "https://bitcoin.org/en/bitcoin-paper")!
}
