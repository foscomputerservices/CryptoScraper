// AssetImporter+Exchanges.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

// Design § 2.7, "The exchange tables too": each exchange chain's rows from two public sources, the exchange's own
// listing for the wire names and decimals and CoinGecko's tickers on that exchange for the class, by CoinGecko's coin
// id, never by a symbol. Pure over decoded answers, as the namespaces' generation is.

public extension AssetImporter {
    /// An exchange whose table the importer generates: Kraken and Binance
    ///
    /// Coinbase is not one: its public products state increments, not decimals. Hyperliquid is not one: CoinGecko's
    /// tickers read answers no ticker for it (recorded 2026-10-07). Both tables stay hand-written.
    enum Exchange: String, CaseIterable, Hashable, Sendable {
        /// Kraken spot: its Assets answer, each asset's key, its alternative name and its decimals
        case kraken
        /// Binance spot: its exchange information, each symbol's base and quote assets and their precisions
        case binance

        /// CoinGecko's id for the exchange, the one ``CoinGeckoAggregator/exchangeTickers(exchange:)`` takes
        public var coinGeckoId: String { rawValue }

        /// The exchange's public listing, asked with no key
        public var listingURL: URL {
            switch self {
            case .kraken: URL(string: "https://api.kraken.com/0/public/Assets")!
            case .binance: URL(string: "https://api.binance.com/api/v3/exchangeInfo")!
            }
        }

        /// The generated file's name: "KrakenExchangeChain+Imported.swift"
        public var fileName: String { "\(chainType)+Imported.swift" }

        /// The assets the listing states, each once: Kraken's by its key's order, Binance's in the order its symbols
        /// first name them
        ///
        /// - Throws: the decoder's error when `data` is not the listing's shape
        public func listing(from data: Data) throws -> [ListedAsset] {
            switch self {
            case .kraken:
                let answer = try JSONDecoder().decode(KrakenAssetsAnswer.self, from: data)
                return answer.result.keys.sorted().map { key in
                    let entry = answer.result[key]!
                    return ListedAsset(
                        wireNames: entry.altname == key ? [key] : [entry.altname, key],
                        decimals: entry.decimals
                    )
                }
            case .binance:
                let answer = try JSONDecoder().decode(BinanceExchangeInformation.self, from: data)
                var listed: [ListedAsset] = []
                for symbol in answer.symbols {
                    for (asset, precision) in [
                        (symbol.baseAsset, symbol.baseAssetPrecision),
                        (symbol.quoteAsset, symbol.quoteAssetPrecision)
                    ] where !listed.contains(where: { $0.wireNames == [asset] }) {
                        listed.append(ListedAsset(wireNames: [asset], decimals: precision))
                    }
                }
                return listed
            }
        }

        var chainType: String {
            switch self {
            case .kraken: "KrakenExchangeChain"
            case .binance: "BinanceExchangeChain"
            }
        }

        var holdingType: String {
            switch self {
            case .kraken: "KrakenHolding"
            case .binance: "BinanceHolding"
            }
        }

        var chainId: String {
            switch self {
            case .kraken: EXCHANGE.Kraken.chainId
            case .binance: EXCHANGE.Binance.chainId
            }
        }

        var listingName: String {
            switch self {
            case .kraken: "Kraken's Assets answer"
            case .binance: "Binance's exchange information"
            }
        }
    }

    /// One asset an exchange's listing states: its names on the wire, the one the exchange accepts in an order first,
    /// and its decimals
    struct ListedAsset: Hashable, Sendable {
        /// "XBT", "XXBT": Kraken's alternative name, then its key where the two differ
        public let wireNames: [String]
        /// The decimals the listing states
        public let decimals: Int

        public init(wireNames: [String], decimals: Int) {
            self.wireNames = wireNames
            self.decimals = decimals
        }
    }

    /// The exchange's `+Imported.swift` text and the report
    ///
    /// Each listed asset whose wire name CoinGecko's tickers on the exchange give a coin id becomes a row: its holding
    /// keyed by its first wire name, its decimals as listed, its symbol its first wire name, its class the
    /// conformer's for an admitted chain's own coin (``nativePaths``, every admitted chain's), the generated `Assets`
    /// constant for a coin `generated` declares, `nil` for any other coin. An asset with no coin id is left out and reported; it belongs in the exchange's overrides.
    ///
    /// Regeneration, given `previous`: a row generated before keeps its place, its decimals and its class, and new
    /// wire names join it. A changed decimals is refused and reported (`decimalsChanged`); a changed class is
    /// refused and reported (`classChanged`); a class where there was none is taken. A row the listing no longer
    /// states is carried as it was.
    ///
    /// - Parameters:
    ///   - exchange: the exchange
    ///   - listing: its listing's assets, from ``Exchange/listing(from:)``
    ///   - tickers: CoinGecko's tickers on the exchange
    ///   - generated: the namespaces' and `Assets`' files of the same run, from
    ///     ``generate(coins:date:previous:chainDecimals:)``,
    ///     whose declarations are the classes a row can name
    ///   - date: the day the answers were read, written in the header
    ///   - previous: the exchange's file as last generated; `nil` on a first run
    static func generate(
        exchange: Exchange,
        listing: [ListedAsset],
        tickers: [CoinGeckoTickerResponse],
        generated: [String: String],
        date: String,
        previous: String? = nil
    ) -> (file: String, report: Report) {
        var findings: [Finding] = []

        // Each wire name to the first coin id a ticker gives it, as base or as quote
        var coinIds: [String: String] = [:]
        for ticker in tickers {
            if let coinId = ticker.coinId, coinIds[ticker.base] == nil {
                coinIds[ticker.base] = coinId
            }
            if let coinId = ticker.targetCoinId, coinIds[ticker.target] == nil {
                coinIds[ticker.target] = coinId
            }
        }
        let declarations = Previous(files: generated).declarations

        var fresh: [ExchangeRow] = []
        for asset in listing {
            guard let wireName = asset.wireNames.first else {
                continue
            }
            guard let coinId = asset.wireNames.lazy.compactMap({ coinIds[$0] }).first else {
                findings.append(.noCoinId(exchange: exchange.rawValue, wireName: wireName))
                continue
            }
            let assetClass: String? = if let native = nativePaths[coinId] {
                "try! Asset(validating: \(native).instance.id)"
            } else if let declaration = declarations.first(where: { $0.coinId == coinId }) {
                "Assets.\(identifier(declaration.name)).asset"
            } else {
                nil
            }
            fresh.append(ExchangeRow(
                coinId: coinId, wireNames: asset.wireNames, decimals: asset.decimals, symbol: wireName,
                assetClass: assetClass
            ))
        }

        // The rows generated before keep their place, their decimals and their class; new wire names join them
        var rows = previous.map(ExchangeRow.read) ?? []
        for row in fresh {
            guard let index = rows.firstIndex(where: { $0.holding == row.holding }) else {
                rows.append(row)
                continue
            }
            let old = rows[index]
            var kept = row
            kept.wireNames = old.wireNames + row.wireNames.filter { !old.wireNames.contains($0) }
            if old.decimals != row.decimals {
                findings.append(.decimalsChanged(
                    name: row.holding, chainId: exchange.chainId, kept: old.decimals, refused: row.decimals
                ))
                kept.decimals = old.decimals
            }
            if let oldClass = old.assetClass {
                if let newClass = row.assetClass, newClass != oldClass {
                    findings.append(.classChanged(
                        name: row.holding, chainId: exchange.chainId, kept: oldClass, refused: newClass
                    ))
                }
                kept.assetClass = oldClass
                kept.coinId = old.coinId
            }
            rows[index] = kept
        }

        return (exchangeFile(exchange, rows: rows, date: date), Report(findings: findings))
    }
}

// MARK: The listings' shapes

extension AssetImporter {
    struct KrakenAssetsAnswer: Decodable {
        struct Entry: Decodable {
            let altname: String
            let decimals: Int
        }

        let result: [String: Entry]
    }

    struct BinanceExchangeInformation: Decodable {
        struct Symbol: Decodable {
            let baseAsset: String
            let baseAssetPrecision: Int
            let quoteAsset: String
            let quoteAssetPrecision: Int
        }

        let symbols: [Symbol]
    }

    /// ``natives`` by CoinGecko's id, as the Swift path of the conformer's constant: the class a row of such a coin
    /// names
    static let nativePaths: [String: String] = Dictionary(uniqueKeysWithValues: natives.map { ($0.coinId, $0.path) })
}

// MARK: The row and its text

extension AssetImporter {
    struct ExchangeRow: Hashable, Sendable {
        var coinId: String
        var wireNames: [String]
        var decimals: Int
        var symbol: String
        var assetClass: String?

        /// The holding's key, the first wire name
        var holding: String { wireNames.first ?? "" }

        /// The rows of a file as last generated, read back from their text
        static func read(_ text: String) -> [ExchangeRow] {
            var rows: [ExchangeRow] = []
            var coinId = ""
            for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("// "), let start = line.range(of: "CoinGecko's `") {
                    coinId = String(line[start.upperBound...].prefix { $0 != "`" })
                } else if line.hasPrefix("Row(holding: "),
                          let names = slice(line, from: "wireNames: [", to: "], decimals: "),
                          let decimals = slice(line, from: "], decimals: ", to: ", symbol: \"").flatMap({ Int($0) }),
                          let symbol = slice(line, from: ", symbol: \"", to: "\", asset: "),
                          let assetClass = slice(line, from: "\", asset: ", to: "),", last: true) {
                    rows.append(ExchangeRow(
                        coinId: coinId,
                        wireNames: names.components(separatedBy: ", ").map { unliteral(String($0.dropFirst().dropLast())) },
                        decimals: decimals,
                        symbol: unliteral(symbol),
                        assetClass: assetClass == "nil" ? nil : assetClass
                    ))
                }
            }
            return rows
        }

        private static func slice(_ line: String, from start: String, to end: String, last: Bool = false) -> String? {
            guard let lower = line.range(of: start),
                  let upper = last
                  ? line.range(of: end, options: .backwards)
                  : line.range(of: end, range: lower.upperBound..<line.endIndex),
                  lower.upperBound <= upper.lowerBound else {
                return nil
            }
            return String(line[lower.upperBound..<upper.lowerBound])
        }
    }

    static func exchangeFile(_ exchange: Exchange, rows: [ExchangeRow], date: String) -> String {
        // The namespace enums always imported, and any other a row's native class is written in
        let rowNamespaces = rows.compactMap(\.assetClass).compactMap { assetClass in
            nativePaths.values.first { assetClass.contains($0 + ".") }.flatMap { $0.split(separator: ".").first }.map(String.init)
        }
        let enums = Set(["Assets", "BIP122", "EIP155", "TRON"] + rowNamespaces).sorted()
        var text = header(
            exchange.fileName, date: date, source: "\(exchange.listingName) and CoinGecko's tickers",
            handAdditions: "\(exchange.chainType)+Overrides.swift",
            imports: [
                "import struct CryptoAsset.Asset",
                "import struct CryptoAsset.AssetDeclaration"
            ] + enums.map { "import enum CryptoAsset.\($0)" }
        )
        text += """

            extension \(exchange.chainType) {
                /// The rows generated from \(exchange.listingName) and CoinGecko's tickers: each holding keyed by the
                /// first of its wire names, its class `nil` where the importer generated none
                static let importedRows: [Row] = [

            """
        text += rows.map { row in
            let names = row.wireNames.map { "\"\(literal($0))\"" }.joined(separator: ", ")
            let comment = "        // \(literal(row.holding)): CoinGecko's `\(row.coinId)`"
                + (row.assetClass == nil ? ", no class generated" : "")
            let line = "        Row(holding: \(exchange.holdingType)(address: \"\(literal(row.holding))\"), "
                + "wireNames: [\(names)], decimals: \(row.decimals), symbol: \"\(literal(row.symbol))\", "
                + "asset: \(row.assetClass ?? "nil")),"
            return comment + "\n" + line
        }.joined(separator: "\n")
        text += """

                ]
            }

            """
        return text
    }
}
