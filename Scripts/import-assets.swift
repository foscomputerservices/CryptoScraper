#!/usr/bin/swift sh
// import-assets.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The importer's script (design § 2.7): reads CoinGecko's top coins, each coin's platforms, CoinGecko's tickers on
// Kraken and Binance and the two exchanges' public listings, runs AssetImporter, writes the generated files and prints
// the importer's report. The files it writes are never edited by hand; hand additions go in each namespace's
// hand-written file (EIP155.swift beside EIP155+Imported.swift) and each exchange chain's overrides file.
//
// Run it with swift-sh, from the repository's root:
//
//     swift sh Scripts/import-assets.swift [--top N] [--out <repository root>] [--delay <seconds>]
//     Scripts/import-assets.swift --help
//
//   --top N        the top N coins by market value (default 1000)
//   --out <path>   the repository root the files are read from and written under (default: the current directory):
//                  Sources/CryptoAsset/<NAMESPACE>+Imported.swift, Sources/CryptoAsset/Assets+Imported.swift and
//                  Sources/CryptoOHLCV/<Exchange>ExchangeChain+Imported.swift; the files already there are the ones
//                  last generated, which a changed address, decimals or class never overwrites
//   --delay <s>    the wait between two of CoinGecko's coin details (default: CoinGeckoAggregator.pageDelay)
//   --help         prints these flags and exits, asking nothing of the network
//
// With COIN_GECKO_KEY set, CoinGecko is asked at its pro endpoint with the key in its header; without it, at the
// free endpoint. The key is never printed.

import CryptoScraper // ../
import Foundation

// MARK: The arguments

var top = 1000
var out = FileManager.default.currentDirectoryPath
var delay: Duration = CoinGeckoAggregator.pageDelay

let usage = """
    usage: swift sh Scripts/import-assets.swift [--top N] [--out <repository root>] [--delay <seconds>]

      --top N        the top N coins by market value (default 1000)
      --out <path>   the repository root the files are read from and written under (default: the current directory)
      --delay <s>    the wait between two of CoinGecko's coin details (default: \(CoinGeckoAggregator.pageDelay))
      --help         prints these flags and exits, asking nothing of the network

    With COIN_GECKO_KEY set, CoinGecko is asked at its pro endpoint; without it, at the free endpoint.
    """

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--help", "-h":
        print(usage)
        exit(0)
    case "--top":
        guard let value = arguments.next().flatMap(Int.init), value > 0 else { fail("--top takes a positive number") }
        top = value
    case "--out":
        guard let value = arguments.next() else { fail("--out takes a path") }
        out = (value as NSString).expandingTildeInPath
    case "--delay":
        guard let value = arguments.next().flatMap(Double.init), value >= 0 else { fail("--delay takes seconds") }
        delay = .milliseconds(Int(value * 1000))
    default:
        fail("unknown argument \(argument); use --top N, --out <path>, --delay <seconds>, or --help")
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("import-assets: \(message)\n".utf8))
    exit(1)
}

let started = Date()
let date: String = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: started)
}()

let assetDirectory = URL(fileURLWithPath: out).appending(path: "Sources/CryptoAsset")
let exchangeDirectory = URL(fileURLWithPath: out).appending(path: "Sources/CryptoOHLCV")
let namespaceFileNames = [
    "EIP155+Imported.swift", "BIP122+Imported.swift", "TRON+Imported.swift", "SOLANA+Imported.swift", "XRPL+Imported.swift",
    "STELLAR+Imported.swift", "TEZOS+Imported.swift", "ALGORAND+Imported.swift", "HEDERA+Imported.swift",
    "NEO+Imported.swift", "FIL+Imported.swift", "MVX+Imported.swift", "STACKS+Imported.swift", "IOTA+Imported.swift", "VECHAIN+Imported.swift", "ARWEAVE+Imported.swift", "MINA+Imported.swift", "CONFLUX+Imported.swift", "FLOW+Imported.swift", "COSMOS+Imported.swift", "POLKADOT+Imported.swift", "NEAR+Imported.swift", "CIP34+Imported.swift", "ICP+Imported.swift", "ONT+Imported.swift", "ZIL+Imported.swift", "CKB+Imported.swift", "SIA+Imported.swift", "DCR+Imported.swift", "Assets+Imported.swift"
]

print("import-assets: the top \(top), on \(date), into \(out)")
print(ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] == nil
    ? "CoinGecko: the free endpoint, no key"
    : "CoinGecko: the pro endpoint, a key set (not printed)")

// MARK: Reading, paced, with one patient retry on a refusal

/// The read, and on a failure (CoinGecko's rate limit answers 429) a wait of a minute and up to two more tries
func patiently<T>(_ what: String, _ read: () async throws -> T) async throws -> T {
    var tries = 0
    while true {
        do {
            return try await read()
        } catch {
            tries += 1
            guard tries <= 2 else { throw error }
            print("  \(what) failed (\(error)); waiting 61 s, then try \(tries + 1) of 3")
            try await Task.sleep(for: .seconds(61))
        }
    }
}

func previous(_ directory: URL, _ fileName: String) -> String? {
    try? String(contentsOf: directory.appending(path: fileName), encoding: .utf8)
}

func write(_ text: String, _ directory: URL, _ fileName: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try text.write(to: directory.appending(path: fileName), atomically: true, encoding: .utf8)
    print("  wrote \(directory.appending(path: fileName).path)")
}

func printReport(_ title: String, _ report: AssetImporter.Report) {
    print("\(title): \(report.findings.count) findings")
    for (kind, count) in report.counts.sorted(by: { $0.key < $1.key }) {
        print("  \(kind): \(count)")
    }
    // Every finding but the contracts on chains the library has no conformer for, which are many and only counted
    for finding in report.findings where finding.kind != "chainNotAdmitted" {
        print("    \(finding)")
    }
}

let gecko = CoinGeckoAggregator()

// MARK: The coins

let coins = try await patiently("the top \(top)") { try await gecko.topCoins(count: top) }
print("read the top \(coins.count) coins")

var details: [CoinGeckoCoinResponse] = []
var unread: [String] = []
for (index, coin) in coins.enumerated() {
    if index > 0 { try await Task.sleep(for: delay) }
    do {
        details.append(try await patiently("coin \(coin.id)") { try await gecko.coinDetail(id: coin.id) })
    } catch {
        unread.append(coin.id)
    }
    if (index + 1) % 50 == 0 { print("  read \(index + 1) of \(coins.count) coins' details") }
}
print("read \(details.count) coins' details" + (unread.isEmpty ? "" : "; not read, left out: \(unread.joined(separator: ", "))"))

let namespacePrevious = namespaceFileNames.reduce(into: [String: String]()) { files, fileName in
    files[fileName] = previous(assetDirectory, fileName)
}
let (files, report) = AssetImporter.generate(coins: details, date: date, previous: namespacePrevious)
for fileName in namespaceFileNames {
    try write(files[fileName]!, assetDirectory, fileName)
}
printReport("The coins", report)

// MARK: The exchanges

for exchange in AssetImporter.Exchange.allCases {
    try await Task.sleep(for: delay)
    do {
        let tickers = try await patiently("CoinGecko's tickers on \(exchange.coinGeckoId)") {
            try await gecko.exchangeTickers(exchange: exchange.coinGeckoId)
        }
        let (data, response) = try await URLSession.shared.data(from: exchange.listingURL)
        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "\(exchange.listingURL) answered \((response as? HTTPURLResponse)?.statusCode ?? 0)"])
        }
        let listing = try exchange.listing(from: data)
        print("\(exchange.coinGeckoId): \(tickers.count) tickers, \(listing.count) listed assets")
        let (file, exchangeReport) = AssetImporter.generate(
            exchange: exchange, listing: listing, tickers: tickers, generated: files, date: date,
            previous: previous(exchangeDirectory, exchange.fileName)
        )
        try write(file, exchangeDirectory, exchange.fileName)
        printReport("\(exchange.coinGeckoId)'s table", exchangeReport)
    } catch {
        print("\(exchange.coinGeckoId): not read (\(error)); its file left as it was")
    }
}

print("done in \(Int(Date().timeIntervalSince(started))) s; Hyperliquid's and Coinbase's tables stay hand-written")
