// CoinGeckoReadsNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import Foundation
import Testing

/// Design § 2.7, the importer's three reads: each recorded public answer decodes into its value with the fields the
/// importer reads, and each read asks what was recorded. No network.
@Suite struct CoinGeckoReadsNoNetworkTests {
    @Test func theRecordedTopCoinsDecodeInRankOrder() throws {
        let top = try CoinGeckoRecorded.markets()

        #expect(top.count == 20)
        #expect(top.map(\.marketCapRank) == (1...20).map { Optional($0) })
        #expect(top.prefix(4).map(\.id) == ["bitcoin", "ethereum", "tether", "binancecoin"])
        let usdc = try #require(top.first { $0.id == "usd-coin" })
        #expect(usdc == CoinGeckoMarketResponse(id: "usd-coin", symbol: "usdc", name: "USDC", marketCapRank: 6))
    }

    @Test func aTokensDetailDecodesItsHomeAndEachPlatformsContract() throws {
        let usdc = try CoinGeckoRecorded.coin("usd-coin")

        #expect(usdc.id == "usd-coin")
        #expect(usdc.symbol == "usdc")
        #expect(usdc.name == "USDC")
        #expect(usdc.assetPlatformId == "ethereum")
        #expect(usdc.detailPlatforms.count == 36)
        #expect(usdc.platforms.count == 36)
        #expect(usdc.detailPlatforms["ethereum"] == .init(
            decimalPlace: 6, contractAddress: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        ))
        #expect(usdc.detailPlatforms["tron"] == .init(
            decimalPlace: 6, contractAddress: "TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8"
        ))
        #expect(usdc.platforms["polygon-pos"] == "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359")
    }

    @Test(arguments: ["bitcoin", "ethereum", "solana"])
    func aNativeCoinsDetailHasNoPlatformAndStatesNoDecimals(id: String) throws {
        let native = try CoinGeckoRecorded.coin(id)

        #expect(native.id == id)
        #expect(native.assetPlatformId == nil)
        #expect(native.detailPlatforms == ["": .init(decimalPlace: nil, contractAddress: "")])
        #expect(native.platforms == ["": ""])
    }

    @Test func pepesDetailListsEthereumAndBNBSmartChain() throws {
        let pepe = try CoinGeckoRecorded.coin("pepe")

        #expect(pepe.assetPlatformId == "ethereum")
        #expect(pepe.detailPlatforms["ethereum"] == .init(
            decimalPlace: 18, contractAddress: "0x6982508145454ce325ddbe47a25d4ec3d2311933"
        ))
        #expect(pepe.detailPlatforms["binance-smart-chain"] == .init(
            decimalPlace: 18, contractAddress: "0x25d887ce7a35172c62febfd67a1856f20faebb00"
        ))
    }

    @Test func theRecordedTickersDecodeEachBaseAndQuoteWithCoinGeckosIds() throws {
        let page = try CoinGeckoRecorded.krakenTickers()

        #expect(page.name == "Kraken")
        #expect(page.tickers.count == 100)
        #expect(page.tickers.allSatisfy { $0.market == .init(name: "Kraken", identifier: "kraken") })
        #expect(page.tickers.first == CoinGeckoTickerResponse(
            base: "XBT", target: "USD", coinId: "bitcoin", targetCoinId: nil,
            market: .init(name: "Kraken", identifier: "kraken")
        ))
        let xbtUSDT = try #require(page.tickers.first { $0.base == "XBT" && $0.target == "USDT" })
        #expect(xbtUSDT.coinId == "bitcoin")
        #expect(xbtUSDT.targetCoinId == "tether")
    }

    @Test func eachReadAsksWhatWasRecorded() {
        #expect(CoinGeckoAggregator.marketsQuery(page: 3) == [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "250"),
            URLQueryItem(name: "page", value: "3")
        ])
        #expect(CoinGeckoAggregator.coinDetailQuery().map(\.name) == [
            "localization", "tickers", "market_data", "community_data", "developer_data", "sparkline"
        ])
        #expect(CoinGeckoAggregator.coinDetailQuery().allSatisfy { $0.value == "false" })
        #expect(CoinGeckoAggregator.tickersQuery(page: 2) == [URLQueryItem(name: "page", value: "2")])
        #expect(CoinGeckoAggregator.marketsPerPage == 250)
        #expect(CoinGeckoAggregator.tickersPerPage == 100)
        #expect(CoinGeckoAggregator.pageDelay == .seconds(6))
    }
}
