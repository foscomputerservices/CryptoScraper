// CoinMarketCapAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

public extension CoinMarketCapAggregator {
    /// Returns the coins known to the aggregator
    ///
    /// Reads `/v1/cryptocurrency/map` once per aggregator and keeps the answer for later calls. A coin with no
    /// platform, on a platform the reference table does not map to a known chain, or whose address its chain
    /// refuses, is left out.
    ///
    /// - Throws: ``CoinMarketCapError`` when no key is set (the environment variable `COIN_MARKETCAP_KEY`), or
    ///   ``CoinMarketCapResponseError`` when CoinMarketCap refuses
    ///
    /// - See also: https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyMap
    func tokens<Contract: CryptoContract & Sendable>(for contract: Contract.Type) async throws -> Set<SimpleTokenInfo<Contract>> {
        let response: CurrencyMapResponse

        if let cachedResponse = cachedMapResponse {
            response = cachedResponse
        } else {
            response = try await Self.endPoint
                .appending(path: "v1/cryptocurrency/map")
                .fetch(
                    headers: headers(),
                    errorType: CoinMarketCapResponseError.self
                )

            // Cache the response for later use
            cachedMapResponse = response
        }

        return try response.tokens(for: contract)
    }

    private func headers() throws -> [(field: String, value: String)] {
        guard let apiKey = Self.apiKey else {
            throw CoinMarketCapError(message: "CryptoMarketCapApiKey is not specified")
        }

        return [(field: "X-CMC_PRO_API_KEY", value: apiKey)]
    }
}

struct CurrencyMapResponse: Decodable, Sendable {
    fileprivate let data: [CurrencyMapItem]
    let status: CoinMarketCapError.ErrorStatus

    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try data.tokens(for: contract)
    }
}

private struct CurrencyMapItem: Decodable, Sendable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let isActive: Int
    let status: String?
    let firstHistoricalData: String
    let lastHistoricalData: String?
    let platform: Platform?

    func token<Contract: CryptoContract>(for contract: Contract.Type) throws -> CoinMarketCapTokenInfo<Contract>? {
        guard let platform, let chain = platform.chain else {
            return nil
        }
        guard (chain.mainContract as (any CryptoContract)) is Contract else {
            return nil
        }

        // A token whose address its chain refuses (`BlockChainError.malformedAddress`) is left out, as a platform the
        // table lacks is: one listing the chain cannot read never fails the whole list.
        guard let contract = try? chain.contract(for: platform.tokenAddress) as? Contract else {
            return nil
        }
        return CoinMarketCapTokenInfo(response: self, contract: contract)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case slug
        case isActive = "is_active"
        case status
        case firstHistoricalData = "first_historical_data"
        case lastHistoricalData = "last_historical_data"
        case platform
    }
}

private struct CoinMarketCapTokenInfo<Contract: CryptoContract>: TokenInfo {
    let contractAddress: Contract
    let tokenName: String
    let symbol: String

    init(response: CurrencyMapItem, contract: Contract) {
        self.contractAddress = contract
        self.tokenName = response.name
        self.symbol = response.symbol
    }
}

/// Metadata about the parent cryptocurrency platform this cryptocurrency belongs to
private struct Platform: Decodable, Sendable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let tokenAddress: String

    var chain: (any CryptoChain)? {
        name.chain
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case slug
        case tokenAddress = "token_address"
    }
}

private extension Collection<CurrencyMapItem> {
    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try compactMap { try $0.token(for: contract) }
            .reduce(into: Set<SimpleTokenInfo<Contract>>()) { result, next in
                result.insert(.init(tokenInfo: next))
            }
    }
}

private extension String {
    /// The chain CoinMarketCap calls `self`, through the one table of reference names,
    /// `AssetRegistry.referenceChainIds` (design § 2.4); `nil` for a name the table lacks
    var chain: (any CryptoChain)? {
        guard let chainId = try? AssetRegistry.chainId(named: self, by: .coinMarketCap) else {
            return nil
        }

        return BlockChains.knownBlockChains.first { $0.id == chainId }
    }
}
