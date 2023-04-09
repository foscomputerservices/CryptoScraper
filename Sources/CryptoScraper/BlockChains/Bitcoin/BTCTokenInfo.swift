// BTCTokenInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct BTCTokenInfo: TokenInfo {
    public let contractAddress: BitcoinContract

    public let tokenName: String
    public let symbol: String
    public let whitepaper: URL?

    init(contractAddress: BitcoinContract) {
        self.contractAddress = contractAddress
        self.tokenName = "Bitcoin"
        self.symbol = "BTC"
        self.whitepaper = URL(string: "https://bitcoin.org/en/bitcoin-paper")
    }
}
