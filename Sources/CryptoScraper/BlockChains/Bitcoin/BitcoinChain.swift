// BitcoinChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class BitcoinChain: CryptoChain {
    // MARK: CryptoChain

    public let userReadableName: String = "Bitcoin"

    public var chainTokenInfos: Set<SimpleTokenInfo<BitcoinContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: BitcoinContract!

    public func contract(for address: String) throws -> BitcoinContract {
        BitcoinContract(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: BitcoinContract.self
            )
        )
    }

    private var tokens: [String: SimpleTokenInfo<BitcoinContract>]?
    private func loadChainTokens(from newTokens: any Collection<SimpleTokenInfo<BitcoinContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            // I do not understand why the next line is needed 🤷‍♂️
            let token = token as! SimpleTokenInfo<BitcoinContract>
            tokens![token.contractAddress.address] = token
        }

        // Add the chain's token as it doesn't come from the
        // data aggregators
        tokens![Self.btcContractAddress] = btcTokenInfo
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<BitcoinContract>? {
        tokens?[address]
    }

    public let scanner: BlockChainInfo? = .init()

    static var btcContractAddress: String { "BTC" }

    public static var `default`: BitcoinChain = .init()

    public init() {
        self.mainContract = BitcoinContract(address: Self.btcContractAddress)
    }

    private var btcTokenInfo: SimpleTokenInfo<BitcoinContract> {
        .init(contractAddress: mainContract, equivalentContracts: [], tokenName: "Bitcoin", symbol: "BTC", imageURL: nil, tokenType: nil, totalSupply: nil, blueCheckmark: nil, description: nil, website: nil, email: nil, blog: nil, reddit: nil, slack: nil, facebook: nil, twitter: nil, gitHub: .init(string: "https://github.com/bitcoin"), telegram: nil, wechat: nil, linkedin: nil, discord: nil, whitepaper: .init(string: "https://bitcoin.org/bitcoin.pdf"))
    }
}

public extension CryptoChain where Self == BitcoinChain {
    static var bitcoin: BitcoinChain { .default }
}
