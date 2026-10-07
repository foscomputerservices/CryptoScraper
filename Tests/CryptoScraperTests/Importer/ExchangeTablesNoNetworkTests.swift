// ExchangeTablesNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import Foundation
import Testing

/// Design § 2.7, "The exchange tables too": an exchange's rows from its own listing (wire names, decimals) joined to
/// CoinGecko's tickers on it (the class, by coin id), against the recorded answers. No network.
@Suite struct ExchangeTablesNoNetworkTests {
    static func generated() throws -> [String: String] {
        try AssetImporter.generate(coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date).files
    }

    static func table(
        _ exchange: AssetImporter.Exchange,
        listing: [AssetImporter.ListedAsset]? = nil,
        tickers: [CoinGeckoTickerResponse]? = nil,
        previous: String? = nil
    ) throws -> (file: String, report: AssetImporter.Report) {
        try AssetImporter.generate(
            exchange: exchange,
            listing: listing ?? exchange.listing(from: CoinGeckoRecorded.listing(exchange)),
            tickers: tickers ?? CoinGeckoRecorded.tickers(exchange),
            generated: generated(),
            date: CoinGeckoRecorded.date,
            previous: previous
        )
    }

    // MARK: The listings

    @Test func krakensRecordedAssetsAnswerListsItsFourAssetsByKey() throws {
        let listed = try AssetImporter.Exchange.kraken.listing(from: CoinGeckoRecorded.listing(.kraken))

        #expect(listed == [
            .init(wireNames: ["SOL"], decimals: 10),
            .init(wireNames: ["ETH", "XETH"], decimals: 10),
            .init(wireNames: ["XBT", "XXBT"], decimals: 10),
            .init(wireNames: ["USD", "ZUSD"], decimals: 4)
        ])
    }

    @Test func binancesRecordedExchangeInformationListsBTCAndUSDTAtEight() throws {
        let listed = try AssetImporter.Exchange.binance.listing(from: CoinGeckoRecorded.listing(.binance))

        #expect(listed == [.init(wireNames: ["BTC"], decimals: 8), .init(wireNames: ["USDT"], decimals: 8)])
    }

    // MARK: The generated text

    @Test(arguments: AssetImporter.Exchange.allCases)
    func theRecordedAnswersGenerateTheExpectedExchangeFileByteForByte(exchange: AssetImporter.Exchange) throws {
        let (file, _) = try Self.table(exchange)

        #expect(file == CoinGeckoRecorded.expected(exchange.fileName))
    }

    @Test func krakensDollarHasNoCoinIdAndIsLeftOutForTheOverrides() throws {
        let (_, report) = try Self.table(.kraken)

        #expect(report.findings == [.noCoinId(exchange: "kraken", wireName: "USD")])
    }

    @Test func binancesTwoAssetsBothGenerateAndNothingIsLeftOut() throws {
        let (file, report) = try Self.table(.binance)

        #expect(report.findings.isEmpty)
        #expect(AssetImporter.ExchangeRow.read(file).map(\.holding) == ["BTC", "USDT"])
    }

    @Test func aChainsOwnCoinsClassIsTheConformersAGeneratedCoinsIsItsAssetsConstantAnyOtherIsNil() throws {
        let rows = try AssetImporter.ExchangeRow.read(Self.table(.kraken).file)
            + AssetImporter.ExchangeRow.read(Self.table(.binance).file)
        let classes = Dictionary(rows.map { ($0.holding, $0.assetClass) }, uniquingKeysWith: { first, _ in first })

        #expect(classes["XBT"] == "try! Asset(validating: BIP122.Bitcoin.btc.instance.id)")
        #expect(classes["ETH"] == "try! Asset(validating: EIP155.Ethereum.eth.instance.id)")
        #expect(classes["USDT"] == "Assets.tether.asset")
        #expect(classes["SOL"] == "try! Asset(validating: SOLANA.Solana.sol.instance.id)")
    }

    // An exchange file's hand additions live in its exchange chain's overrides file
    @Test(arguments: AssetImporter.Exchange.allCases)
    func anExchangeFilesHeaderSendsHandAdditionsToItsOverridesFile(exchange: AssetImporter.Exchange) throws {
        let (file, _) = try Self.table(exchange)
        let overrides = exchange.fileName.replacingOccurrences(of: "+Imported", with: "+Overrides")
        #expect(file.contains("hand additions go in \(overrides)."))
    }

    @Test func aRowsHoldingIsItsFirstWireNameAndItsSymbolTheSame() throws {
        let rows = try AssetImporter.ExchangeRow.read(Self.table(.kraken).file)

        #expect(rows.map(\.wireNames) == [["SOL"], ["ETH", "XETH"], ["XBT", "XXBT"]])
        #expect(rows.allSatisfy { $0.symbol == $0.holding })
        #expect(rows.map(\.decimals) == [10, 10, 10])
    }

    // MARK: Regeneration

    @Test func regeneratingTheExchangeFileFromTheSameAnswerChangesNothing() throws {
        let (first, _) = try Self.table(.kraken)
        let (second, report) = try Self.table(.kraken, previous: first)

        #expect(second == first)
        #expect(report.findings == [.noCoinId(exchange: "kraken", wireName: "USD")])
    }

    @Test func aChangedDecimalsInTheListingIsRefusedAndReported() throws {
        let (first, _) = try Self.table(.binance)
        let (second, report) = try Self.table(
            .binance,
            listing: [.init(wireNames: ["BTC"], decimals: 6), .init(wireNames: ["USDT"], decimals: 8)],
            previous: first
        )

        #expect(second == first)
        #expect(report.findings == [.decimalsChanged(name: "BTC", chainId: EXCHANGE.Binance.chainId, kept: 8, refused: 6)])
    }

    @Test func aChangedClassIsRefusedAndReported() throws {
        let (first, _) = try Self.table(.binance)
        // Every ticker naming BTC, as base or as quote, now says CoinGecko's tether
        let tickers = try CoinGeckoRecorded.tickers(.binance).map { ticker in
            CoinGeckoTickerResponse(
                base: ticker.base, target: ticker.target,
                coinId: ticker.base == "BTC" ? "tether" : ticker.coinId,
                targetCoinId: ticker.target == "BTC" ? "tether" : ticker.targetCoinId,
                market: ticker.market
            )
        }
        let (second, report) = try Self.table(.binance, tickers: tickers, previous: first)

        #expect(second == first)
        #expect(report.findings == [.classChanged(
            name: "BTC", chainId: EXCHANGE.Binance.chainId,
            kept: "try! Asset(validating: BIP122.Bitcoin.btc.instance.id)", refused: "Assets.tether.asset"
        )])
    }

    @Test func aRowTheListingNoLongerStatesIsCarriedAndANewOneAddsAfterIt() throws {
        let (first, _) = try Self.table(.binance)
        let (second, _) = try Self.table(
            .binance, listing: [.init(wireNames: ["ETH"], decimals: 8)], previous: first
        )

        #expect(AssetImporter.ExchangeRow.read(second).map(\.holding) == ["BTC", "USDT", "ETH"])
    }

    @Test func aNewWireNameJoinsItsRowAfterTheOnesBefore() throws {
        let (first, _) = try Self.table(.kraken)
        let (second, _) = try Self.table(
            .kraken, listing: [.init(wireNames: ["XBT", "XXBT", "XBT.F"], decimals: 10)], previous: first
        )

        let xbt = try #require(AssetImporter.ExchangeRow.read(second).first { $0.holding == "XBT" })
        #expect(xbt.wireNames == ["XBT", "XXBT", "XBT.F"])
    }
}
