// CoinMarketCapAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinMarketCapAggregator {
    /// Returns the coins known to the aggregator
    ///
    /// - See also: https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyMap
    func listCoins() async throws -> [CryptoInfo] {
        let response: CurrencyMapResponse = try await Self.endPoint
            .appending(path: "v1/cryptocurrency/map")
            .fetch(
                headers: try headers(),
                errorType: CoinMarketCapResponseError.self
            )

        return try response.coins()
    }

    private func headers() throws -> [(field: String, value: String)] {
        guard let apiKey = Self.apiKey else {
            throw CoinMarketCapError(message: "CryptoMarketCapApiKey is not specified")
        }

        return [(field: "X-CMC_PRO_API_KEY", value: apiKey)]
    }
}

private struct CurrencyMapResponse: Decodable {
    let data: [CurrencyMapItem]
    let status: CoinMarketCapError.ErrorStatus

    func coins() throws -> [CryptoInfo] {
        try data.coins()
    }
}

private struct CurrencyMapItem: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let isActive: Int
    let status: String?
    let firstHistoricalData: String
    let lastHistoricalData: String
    let platform: Platform?

    func coin() throws -> CryptoInfo? {
        try TokenInfo(self)
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

private struct TokenInfo: CryptoInfo {
    let contractAddress: CryptoContract
    let tokenName: String
    let symbol: String
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
    let whitepaper: URL? = nil

    init?(_ response: CurrencyMapItem) throws {
        guard let platform = response.platform, let chain = platform.chain else { return nil }

        self.contractAddress = try chain.contract(for: platform.tokenAddress)
        self.tokenName = response.name
        self.symbol = response.symbol
    }
}

/// Metadata about the parent cryptocurrency platform this cryptocurrency belongs to
private struct Platform: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let tokenAddress: String

    var chain: CryptoChain? {
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
    func coins() throws -> [CryptoInfo] {
        try compactMap { try $0.coin() }
    }
}

private var unknownChain = Set<String>()

private extension String {
    var chain: CryptoChain? {
        switch self {
        case "Ethereum": return .ethereum
        case "Fantom": return .fantom
        case "BNB": return .binance
        case "Polygon": return .polygon
        case "Optimism": return .optimism

        // TODO: Unsupported chains
        case "Bitcicoin", "Chiliz", "Telos", "Super Zero Protocol", "KardiaChain", "Waves", "Velas", "Cardano", "EthereumPoW", "EOS", "XRP", "Energi", "RSK Smart Bitcoin", "IoTeX", "Fuse Network", "Conflux", "SX Network", "Algorand", "Moonriver", "HTMLCOIN", "CANTO", "Ethereum Classic", "Step App", "Terra Classic", "Secret", "DeFi Kingdoms", "Astar", "Oasis Network", "Boba Network", "Celo", "Cosmos", "OKC Token", "SORA", "XDC Network", "Songbird", "Osmosis", "MultiversX", "Karura", "Ontology", "Tezos", "Klaytn", "Wanchain", "VeChain", "Polkadot", "Cronos", "TomoChain", "TRON", "KuCoin Token", "Avalanche", "Aurora", "MetisDAO", "Aptos", "Solana", "Harmony", "Meter Governance", "Toncoin", "Hedera", "Huobi Token", "NEAR Protocol", "NEM", "Bitcoin Cash", "Zilliqa", "Evmos", "Stellar", "Stacks", "Elastos", "Everscale", "Bitgert", "Dogecoin", "Gnosis", "Fusion", "Neo", "Moonbeam", "Terra":
            return nil

        default:
            #if DEBUG
            if !unknownChain.contains(self) {
                unknownChain.insert(self)
                print("\(self)")
            }
            #endif
            return nil
        }
    }
}
