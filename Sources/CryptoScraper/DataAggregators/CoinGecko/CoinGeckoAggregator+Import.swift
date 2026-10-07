// CoinGeckoAggregator+Import.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// The three reads the importer needs (design § 2.7): the top coins by market value, one coin's platforms with their
// contract addresses and decimals, and one exchange's tickers with CoinGecko's coin id for each base and quote.
// Extensions on the concrete aggregator only; `CryptoDataAggregator` is unchanged.

public extension CoinGeckoAggregator {
    /// The top `count` coins by market value, in CoinGecko's rank order
    ///
    /// Reads `/coins/markets` 250 coins a page, waiting ``CoinGeckoAggregator/pageDelay`` between pages, the free
    /// endpoint's rate limit.
    ///
    /// ```swift
    /// let top = try await CoinGeckoAggregator().topCoins(count: 1000)
    /// top.first?.id        // "bitcoin"
    /// ```
    ///
    /// - Throws: ``CoinGeckoError`` when CoinGecko refuses, or the fetch's error
    func topCoins(count: Int) async throws -> [CoinGeckoMarketResponse] {
        var coins: [CoinGeckoMarketResponse] = []
        var page = 1
        while coins.count < count {
            if page > 1 {
                try await Task.sleep(for: Self.pageDelay)
            }
            let rows: [CoinGeckoMarketResponse] = try await Self.endPoint
                .appending(path: "coins/markets")
                .appending(queryItems: Self.marketsQuery(page: page))
                .fetch(headers: Self.headers(), errorType: CoinGeckoError.self)
            coins += rows
            guard rows.count == Self.marketsPerPage else {
                break
            }
            page += 1
        }

        return Array(coins.prefix(count))
    }

    /// One coin's platforms: the chain CoinGecko marks as its own, and its contract address and decimals on each
    ///
    /// Reads `/coins/{id}` without its tickers, market data, community data, developer data or translations.
    ///
    /// ```swift
    /// let usdc = try await CoinGeckoAggregator().coinDetail(id: "usd-coin")
    /// usdc.detailPlatforms["ethereum"]?.decimalPlace      // 6
    /// ```
    ///
    /// - Throws: ``CoinGeckoError`` when CoinGecko refuses, or the fetch's error
    func coinDetail(id: String) async throws -> CoinGeckoCoinResponse {
        try await Self.endPoint
            .appending(path: "coins/\(id)")
            .appending(queryItems: Self.coinDetailQuery())
            .fetch(headers: Self.headers(), errorType: CoinGeckoError.self)
    }

    /// Every ticker CoinGecko lists for the exchange it calls `exchange`, each base and quote with CoinGecko's coin id
    ///
    /// Reads `/exchanges/{id}/tickers` page by page until a page comes back short, waiting
    /// ``CoinGeckoAggregator/pageDelay`` between pages.
    ///
    /// ```swift
    /// let kraken = try await CoinGeckoAggregator().exchangeTickers(exchange: "kraken")
    /// kraken.first { $0.base == "XBT" }?.coinId        // "bitcoin"
    /// ```
    ///
    /// - Throws: ``CoinGeckoError`` when CoinGecko refuses, or the fetch's error
    func exchangeTickers(exchange: String) async throws -> [CoinGeckoTickerResponse] {
        var tickers: [CoinGeckoTickerResponse] = []
        var page = 1
        while true {
            if page > 1 {
                try await Task.sleep(for: Self.pageDelay)
            }
            let answer: CoinGeckoTickersPage = try await Self.endPoint
                .appending(path: "exchanges/\(exchange)/tickers")
                .appending(queryItems: Self.tickersQuery(page: page))
                .fetch(headers: Self.headers(), errorType: CoinGeckoError.self)
            tickers += answer.tickers
            guard answer.tickers.count == Self.tickersPerPage else {
                break
            }
            page += 1
        }

        return tickers
    }

    /// The wait between two pages of one read: 6 seconds, ten calls a minute, under the free endpoint's limit
    static let pageDelay: Duration = .seconds(6)
}

extension CoinGeckoAggregator {
    static let marketsPerPage = 250
    static let tickersPerPage = 100

    static func marketsQuery(page: Int) -> [URLQueryItem] { [
        .init(name: "vs_currency", value: "usd"),
        .init(name: "order", value: "market_cap_desc"),
        .init(name: "per_page", value: String(marketsPerPage)),
        .init(name: "page", value: String(page))
    ] }

    static func coinDetailQuery() -> [URLQueryItem] { [
        .init(name: "localization", value: "false"),
        .init(name: "tickers", value: "false"),
        .init(name: "market_data", value: "false"),
        .init(name: "community_data", value: "false"),
        .init(name: "developer_data", value: "false"),
        .init(name: "sparkline", value: "false")
    ] }

    static func tickersQuery(page: Int) -> [URLQueryItem] { [
        .init(name: "page", value: String(page))
    ] }
}

/// One row of CoinGecko's `/coins/markets`: a coin and its rank by market value
public struct CoinGeckoMarketResponse: Decodable, Hashable, Sendable {
    /// CoinGecko's stable id for the coin: "usd-coin"
    public let id: String
    /// The symbol as CoinGecko writes it, lower-cased: "usdc"
    public let symbol: String
    /// The coin's name: "USDC"
    public let name: String
    /// Its rank by market value; `nil` where CoinGecko ranks it not
    public let marketCapRank: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case marketCapRank = "market_cap_rank"
    }
}

/// CoinGecko's `/coins/{id}`: a coin, the platform CoinGecko marks as its own, and its contract on each platform
public struct CoinGeckoCoinResponse: Decodable, Hashable, Sendable {
    /// CoinGecko's stable id for the coin: "usd-coin"
    public let id: String
    /// The symbol as CoinGecko writes it, lower-cased: "usdc"
    public let symbol: String
    /// The coin's name: "USDC"
    public let name: String
    /// The platform CoinGecko marks as the coin's own: "ethereum"; `nil` for a chain's native coin
    public let assetPlatformId: String?
    /// Each platform's contract address, by CoinGecko's platform id; a native coin lists one empty platform
    public let platforms: [String: String?]
    /// Each platform's contract address and decimals, by CoinGecko's platform id
    public let detailPlatforms: [String: DetailPlatform]

    /// One platform's contract: its address as CoinGecko gives it and its decimals
    public struct DetailPlatform: Decodable, Hashable, Sendable {
        /// The contract's decimals; `nil` where CoinGecko states none, as for a native coin
        public let decimalPlace: Int?
        /// The contract's address as CoinGecko gives it; empty for a native coin
        public let contractAddress: String

        enum CodingKeys: String, CodingKey {
            case decimalPlace = "decimal_place"
            case contractAddress = "contract_address"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case assetPlatformId = "asset_platform_id"
        case platforms
        case detailPlatforms = "detail_platforms"
    }
}

/// One ticker of CoinGecko's `/exchanges/{id}/tickers`: the exchange's base and quote, each with CoinGecko's coin id
public struct CoinGeckoTickerResponse: Decodable, Hashable, Sendable {
    /// The base as the exchange names it: "XBT"
    public let base: String
    /// The quote as the exchange names it: "USD"
    public let target: String
    /// CoinGecko's coin id for the base: "bitcoin"
    public let coinId: String?
    /// CoinGecko's coin id for the quote: "tether"; `nil` for a fiat
    public let targetCoinId: String?
    /// The exchange the ticker is on
    public let market: Market

    /// The exchange, as CoinGecko names it
    public struct Market: Decodable, Hashable, Sendable {
        /// "Kraken"
        public let name: String
        /// CoinGecko's id for the exchange: "kraken"
        public let identifier: String
    }

    enum CodingKeys: String, CodingKey {
        case base
        case target
        case coinId = "coin_id"
        case targetCoinId = "target_coin_id"
        case market
    }
}

/// One page of `/exchanges/{id}/tickers`
struct CoinGeckoTickersPage: Decodable, Sendable {
    let name: String
    let tickers: [CoinGeckoTickerResponse]
}
