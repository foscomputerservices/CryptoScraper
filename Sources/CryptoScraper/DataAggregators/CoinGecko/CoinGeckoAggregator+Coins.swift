// CoinGeckoAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinGeckoAggregator {
    /// Returns the coins known to the aggregator
    func listCoins() async throws -> [CryptoInfo] {
        let response: [CoinResponse] = try await Self.endPoint
            .appending(path: "coins/list")
            .appending(
                queryItems: CoinsResponse.httpQuery()
            ).fetch(errorType: CoinGeckoError.self)

        return try response.coins()
    }
}

private struct CoinsResponse: Decodable {
    // https://www.coingecko.com/en/api/documentation
    static func httpQuery() -> [URLQueryItem] { [
        .init(name: "include_platform", value: "true")
    ] }
}

private struct CoinResponse: Decodable {
    let id: String
    let symbol: String
    let name: String
    let platforms: [String: String?]

    func coins() throws -> [CryptoInfo] {
        try Coin.coins(from: self)
    }

    private struct Coin: CryptoInfo {
        let contractAddress: CryptoContract
        let tokenName: String
        let symbol: String
        let tokenType: String?
        let totalSupply: CryptoAmount?
        let blueCheckmark: Bool?
        let description: String?
        let website: URL?
        let email: String?
        let blog: URL?
        let reddit: URL?
        let slack: String?
        let facebook: URL?
        let twitter: URL?
        let gitHub: URL?
        let telegram: URL?
        let wechat: URL?
        let linkedin: URL?
        let discord: URL?
        let whitepaper: URL?

        static func coins(from coinResponse: CoinResponse) throws -> [CryptoInfo] {
            var result = [Coin]()

            for platform in coinResponse.platforms where platform.value != nil && (!platform.key.isEmpty && !platform.value!.isEmpty) {
                guard let chain = platform.key.chain else {
                    continue
                }
                let contractAddress = try chain.contract(for: platform.value!)

                result.append(.init(contractAddress: contractAddress, coinResponse: coinResponse))
            }

            return result
        }

        private init(contractAddress: CryptoContract, coinResponse: CoinResponse) {
            self.contractAddress = contractAddress
            self.tokenName = coinResponse.name
            self.symbol = coinResponse.symbol
            self.tokenType = nil
            self.totalSupply = nil
            self.blueCheckmark = nil
            self.description = nil
            self.website = nil
            self.email = nil
            self.blog = nil
            self.reddit = nil
            self.slack = nil
            self.facebook = nil
            self.twitter = nil
            self.gitHub = nil
            self.telegram = nil
            self.wechat = nil
            self.linkedin = nil
            self.discord = nil
            self.whitepaper = nil
        }
    }
}

private extension Collection<CoinResponse> {
    func coins() throws -> [CryptoInfo] {
        try reduce(into: [CryptoInfo]()) { result, next in
            for coin in try next.coins() {
                result.append(coin)
            }
        }
    }
}

private extension String {
    var chain: CryptoChain? {
        switch self {
        case "ethereum": return .ethereum
        default: return nil
        }
    }
}
