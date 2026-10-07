// CoinGeckoAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

public extension CoinGeckoAggregator {
    /// Returns the known tokens for a given ``CryptoContract`` type
    ///
    /// Reads `/coins/list` with each coin's platforms once per aggregator and keeps the answer for later calls. A
    /// contract on a platform the reference table does not map to a known chain, or whose address its chain refuses,
    /// is left out.
    func tokens<Contract: CryptoContract & Sendable>(for contract: Contract.Type) async throws -> Set<SimpleTokenInfo<Contract>> {
        let response: [CoinGeckoTokenResponse]
        if let cachedTokensResponse {
            response = cachedTokensResponse
        } else {
            response = try await Self.endPoint
                .appending(path: "coins/list")
                .appending(
                    queryItems: TokensResponse.httpQuery()
                ).fetch(headers: Self.headers(), errorType: CoinGeckoError.self)
            cachedTokensResponse = response
        }

        return try response.tokens(for: contract)
    }
}

private struct TokensResponse: Decodable {
    // https://www.coingecko.com/en/api/documentation
    static func httpQuery() -> [URLQueryItem] { [
        .init(name: "include_platform", value: "true")
    ] }
}

protocol CoinGeckoTokenInfo: TokenInfo {
    var coinGeckoId: String { get }
    var coinGeckoSymbol: String { get }
    var coinGeckoName: String { get }
    var coinGeckoPlatforms: [String: String?] { get }
}

extension SimpleTokenInfo<BitcoinContract>: CoinGeckoTokenInfo {
    var coinGeckoId: String {
        "bitcoin"
    }
    
    var coinGeckoSymbol: String {
        "btc"
    }
    
    var coinGeckoName: String {
        "btc"
    }
    
    var coinGeckoPlatforms: [String : String?] {
        [:]
    }
}

struct CoinGeckoTokenResponse: Decodable {
    let id: String
    let symbol: String
    let name: String
    let platforms: [String: String?]

    fileprivate func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> [Token<Contract>] {
        let contracts = try equivalentContracts()

        return try contracts.reduce(into: [Token<Contract>]()) { result, next in
            let chain = next.chain as (any CryptoChain)
            let mainContract = chain.mainContract as (any CryptoContract)

            guard type(of: mainContract) == Contract.self else {
                return
            }

            try result.append(Token(
                contractAddress: chain.contract(for: next.address) as! Contract,
                tokenResponse: self,
                equivalentContracts: contracts
                    .filter { $0.isSame(as: next) }
                    .map { $0 as! Contract }
            ))
        }
    }

    fileprivate struct Token<Contract: CryptoContract>: CoinGeckoTokenInfo {
        // MARK: TokenInfo

        let contractAddress: Contract
        let equivalentContracts: [Contract]
        let tokenName: String
        let symbol: String
        var aggregatorId: String? { coinGeckoId }

        // MARK: CoinGeckoTokenInfo
        let coinGeckoId: String
        var coinGeckoName: String { tokenName }
        var coinGeckoSymbol: String { symbol }
        let coinGeckoPlatforms: [String : String?]

        init(contractAddress: Contract, tokenResponse: CoinGeckoTokenResponse, equivalentContracts: [Contract]) {
            self.contractAddress = contractAddress
            self.tokenName = tokenResponse.name
            self.symbol = tokenResponse.symbol
            self.equivalentContracts = equivalentContracts
            self.coinGeckoId = tokenResponse.id
            self.coinGeckoPlatforms = tokenResponse.platforms
        }
    }

    // A contract whose address its chain refuses (`BlockChainError.malformedAddress`) is left out, as a platform the
    // table lacks is: one listing the chain cannot read never fails the whole list.
    private func equivalentContracts() throws -> [any CryptoContract] {
        platforms.compactMap { platform, contractId in
            guard
                let chain = platform.chain,
                let contractId,
                !contractId.isEmpty
            else {
                return nil
            }

            return try? chain.contract(for: contractId) as (any CryptoContract)
        }
    }
}

private extension Collection<CoinGeckoTokenResponse> {
    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try reduce(into: Set<SimpleTokenInfo<Contract>>()) { result, next in
            for token in try next.tokens(for: contract) {
                result.insert(.init(tokenInfo: token))
            }
        }
    }
}

private extension String {
    /// The chain CoinGecko calls `self`, through the one table of reference names,
    /// `AssetRegistry.referenceChainIds` (design § 2.4); `nil` for a name the table lacks
    var chain: (any CryptoChain)? {
        guard let chainId = try? AssetRegistry.chainId(named: self, by: .coinGecko) else {
            return nil
        }

        return BlockChains.knownBlockChains.first { $0.id == chainId }
    }
}
