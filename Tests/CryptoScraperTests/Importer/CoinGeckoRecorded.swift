// CoinGeckoRecorded.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

// Resources/CoinGecko holds CoinGecko's public answers, recorded once on 2026-10-07 from the free endpoint
// (https://api.coingecko.com/api/v3) without a key: /coins/markets page 1 at per_page=20; /coins/{id} for usd-coin,
// tether, bitcoin, ethereum, solana and pepe, asked as `coinDetail(id:)` asks (no tickers, market, community or
// developer data, no translations); /exchanges/kraken/tickers page 1; and /exchanges/binance/tickers page 1, recorded the
// same way and day in step 8b. Resources/Kraken/assets.json and Resources/Binance/exchangeinfo-btcusdt.json are copies
// of the exchanges' public listings recorded for CryptoKrakenTests (2026-10-06) and CryptoOHLCVTests (2026-10-04).
// Resources/CoinGecko/Expected holds the files the importer generates from these, pinned byte for byte.

enum CoinGeckoRecorded {
    static func data(_ path: String) -> Data {
        // SwiftPM lays a `.copy("Resources")` folder at the bundle's root on one toolchain and inside `Resources/` on
        // another, so both places are tried.
        let base = Bundle.module.resourceURL!
        for candidate in [base.appendingPathComponent("Resources/\(path)"), base.appendingPathComponent(path)] {
            if let data = try? Data(contentsOf: candidate) { return data }
        }
        fatalError("No recorded fixture \(path) under \(base.path)")
    }

    static func text(_ path: String) -> String {
        String(decoding: data(path), as: UTF8.self)
    }

    static func markets() throws -> [CoinGeckoMarketResponse] {
        try data("CoinGecko/markets-page1-per20.json").fromJSON()
    }

    static func coin(_ id: String) throws -> CoinGeckoCoinResponse {
        try data("CoinGecko/coin-\(id).json").fromJSON()
    }

    static func krakenTickers() throws -> CoinGeckoTickersPage {
        try data("CoinGecko/exchange-kraken-tickers-page1.json").fromJSON()
    }

    static func binanceTickers() throws -> CoinGeckoTickersPage {
        try data("CoinGecko/exchange-binance-tickers-page1.json").fromJSON()
    }

    /// An exchange's recorded listing as the exchange answers it: the recording's first line, a `//` note of where it
    /// came from, left out
    static func listing(_ exchange: AssetImporter.Exchange) -> Data {
        let path = switch exchange {
        case .kraken: "Kraken/assets.json"
        case .binance: "Binance/exchangeinfo-btcusdt.json"
        }
        let lines = text(path).split(separator: "\n", omittingEmptySubsequences: false)
        return Data(lines.drop { $0.hasPrefix("//") }.joined(separator: "\n").utf8)
    }

    static func tickers(_ exchange: AssetImporter.Exchange) throws -> [CoinGeckoTickerResponse] {
        switch exchange {
        case .kraken: try krakenTickers().tickers
        case .binance: try binanceTickers().tickers
        }
    }

    static let expectedExchangeFileNames = AssetImporter.Exchange.allCases.map(\.fileName)

    /// The six recorded details in the top's rank order: the five of the top twenty, then pepe (rank 60)
    static func sixCoins() throws -> [CoinGeckoCoinResponse] {
        try ["bitcoin", "ethereum", "tether", "usd-coin", "solana", "pepe"].map(coin)
    }

    static let date = "2026-10-07"

    /// The decimals the admitted chains' scanners state for a token in their recorded answers, by chain id, then
    /// address (design § 4.1, the chain's scanner the oracle): Algorand's node for USDC (ASA 31566704), and
    /// Etherscan's USDC transfers on Ethereum, each stating its `tokenDecimal`
    static func chainDecimals() throws -> [String: [String: Int]] {
        let usdcOnAlgorand: AlgoNode.AssetResponse = try data("Algorand/asset-31566704.json").fromJSON()
        let algorand = try #require(
            usdcOnAlgorand.tokenInfo(for: AlgorandChain.default.contract(for: "31566704")).decimals
        )

        let transfers = try #require(
            JSONSerialization.jsonObject(with: data("Etherscan/tokentx-ethereum-usdc.json")) as? [String: Any]
        )
        let first = try #require((transfers["result"] as? [[String: Any]])?.first)
        let address = try #require(first["contractAddress"] as? String)
        let ethereum = try #require((first["tokenDecimal"] as? String).flatMap(Int.init))

        return [
            ALGORAND.Algorand.chainId: ["31566704": algorand],
            EIP155.Ethereum.chainId: [address: ethereum]
        ]
    }

    static let expectedFileNames = [
        "EIP155+Imported.swift", "BIP122+Imported.swift", "TRON+Imported.swift", "SOLANA+Imported.swift",
        "XRPL+Imported.swift", "STELLAR+Imported.swift", "TEZOS+Imported.swift", "ALGORAND+Imported.swift",
        "HEDERA+Imported.swift", "NEO+Imported.swift", "FIL+Imported.swift", "MVX+Imported.swift", "STACKS+Imported.swift", "IOTA+Imported.swift", "VECHAIN+Imported.swift", "ARWEAVE+Imported.swift", "MINA+Imported.swift", "CONFLUX+Imported.swift", "FLOW+Imported.swift", "COSMOS+Imported.swift", "POLKADOT+Imported.swift", "NEAR+Imported.swift", "CIP34+Imported.swift", "ICP+Imported.swift", "ONT+Imported.swift", "ZIL+Imported.swift", "CKB+Imported.swift", "SIA+Imported.swift", "DCR+Imported.swift", "Assets+Imported.swift"
    ]

    static func expected(_ fileName: String) -> String {
        text("CoinGecko/Expected/\(fileName)")
    }
}

extension CoinGeckoCoinResponse {
    /// The same answer with some of its facts replaced
    func with(
        symbol: String? = nil,
        detail platform: String? = nil,
        decimals: Int?? = nil,
        address: String? = nil
    ) -> Self {
        var details = detailPlatforms
        if let platform, let old = details[platform] {
            details[platform] = DetailPlatform(
                decimalPlace: decimals ?? old.decimalPlace,
                contractAddress: address ?? old.contractAddress
            )
        }
        return CoinGeckoCoinResponse(
            id: id, symbol: symbol ?? self.symbol, name: name, assetPlatformId: assetPlatformId,
            platforms: platforms, detailPlatforms: details
        )
    }

    /// A coin of the test's own, on the given platforms
    static func made(
        id: String,
        symbol: String = "fred",
        home: String? = "ethereum",
        on details: [String: (decimals: Int?, address: String)] = ["ethereum": (18, "0x42")]
    ) -> Self {
        CoinGeckoCoinResponse(
            id: id, symbol: symbol, name: "Fred \(id)", assetPlatformId: home,
            platforms: details.mapValues { $0.address as String? },
            detailPlatforms: details.mapValues { DetailPlatform(decimalPlace: $0.decimals, contractAddress: $0.address) }
        )
    }
}
