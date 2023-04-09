// TronChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class TronChain: CryptoChain {
    // MARK: CryptoChain

    public typealias Contract = TronContract

    public let userReadableName: String = "Tron"

    public var chainTokenInfos: Set<SimpleTokenInfo<TronContract>> {
        guard let result = tokens?.values else { return [] }

        return .init(result)
    }

    public private(set) var mainContract: TronContract!

    public func contract(for address: String) throws -> TronContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: TronContract.self
            )
        )
    }

    private var tokens: [String: SimpleTokenInfo<TronContract>]?
    private func loadChainTokens(from newTokens: any Collection<SimpleTokenInfo<TronContract>>) {
        tokens = tokens ?? [:]

        for token in newTokens {
            // I do not understand why the next line is needed 🤷‍♂️
            let token = token as! SimpleTokenInfo<TronContract>
            tokens![token.contractAddress.address] = token
        }
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<TronContract>? {
        tokens?[address]
    }

    public let scanner: TronScan? = .init()

    static let trxContractAddress = "TRX"

    public static let `default`: TronChain = .init()

    private init() {
        self.mainContract = TronContract(address: Self.trxContractAddress)
    }
}

public extension CryptoChain where Self == TronChain {
    static var tron: TronChain { .default }
}

#warning("Do we need this???")
// public struct TRXTokenInfo: TokenInfo {
//    public let contractAddress: TronContract
//
//    public let tokenName: String = "Tron"
//    public let symbol: String = "TRX"
//    public let whitepaper: URL? = URL(string: "https://tron.network/static/doc/white_paper_v_2_0.pdf")!
// }
