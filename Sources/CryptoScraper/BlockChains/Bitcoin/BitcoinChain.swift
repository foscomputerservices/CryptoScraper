// BitcoinChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

public final class BitcoinChain: CryptoChain, Sendable {
    // MARK: CryptoChain Protocol

    public let userReadableName: String = "Bitcoin"

    public var chainTokenInfos: Set<SimpleTokenInfo<BitcoinContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    public let mainContract: BitcoinContract!

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

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<BitcoinContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<BitcoinContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }

            // Add the chain's token as it doesn't come from the
            // data aggregators
            tokens![Self.btcContractAddress] = btcTokenInfo
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<BitcoinContract>? {
        tokens.withLock { $0?[address] }
    }

    public let scanner: BlockChainInfo? = .init()

    static let btcContractAddress: String = "btc"

    public static let `default`: BitcoinChain = .init()

    public init() {
        self.mainContract = BitcoinContract(address: Self.btcContractAddress)
    }

    private var btcTokenInfo: SimpleTokenInfo<BitcoinContract> {
        .init(contractAddress: mainContract, equivalentContracts: [], tokenName: "Bitcoin", symbol: "BTC", imageURL: nil, tokenType: nil, totalSupply: nil, blueCheckmark: nil, description: nil, website: nil, email: nil, blog: nil, reddit: nil, slack: nil, facebook: nil, twitter: nil, gitHub: .init(string: "https://github.com/bitcoin"), telegram: nil, wechat: nil, linkedin: nil, discord: nil, whitepaper: .init(string: "https://bitcoin.org/bitcoin.pdf"), aggregatorId: "bitcoin")
    }
}

public extension CryptoChain where Self == BitcoinChain {
    static var bitcoin: BitcoinChain { .default }
}
