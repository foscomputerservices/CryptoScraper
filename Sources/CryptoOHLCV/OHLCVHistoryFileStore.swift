// OHLCVHistoryFileStore.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// An ``OHLCVHistoryStore`` in plain files, so a retrieval runs with nothing behind it
///
/// One file per market and interval, in the directory the caller names, created on the first append:
/// `<market>_<interval>.jsonl`, the market as its description and the interval as its count and a letter
/// (`BTCUSDT_1d.jsonl`, `ETHUSDT_15m.jsonl`). Characters other than ASCII letters, digits, `-` and `.` in a
/// market's description are written as `%XX`.
///
/// The file is JSON Lines: one JSON object per line, in the order kept, each either
/// `{"bar": <OHLCVClientBar>}` or `{"gap": <OHLCVHistoryGap>}`. A bar and a gap are their own `Codable`
/// encoding through FOSFoundation's `toJSON()`, so a time is UTC text to the millisecond
/// (`"2017-08-17T00:00:00.000Z"`) and every price and amount is CryptoAsset's own exact encoding. An append adds
/// lines at the end and never rewrites a line.
///
/// ```swift
/// let store = OHLCVHistoryFileStore<BinanceMarketName>(directory: URL(filePath: "/tmp/ohlcv"))
/// let retrieval = OHLCVHistoryRetrieval(client: BinanceOHLCVClient(), store: store)
/// try await retrieval.retrieve(market: market, interval: day, from: start, through: end)
/// ```
///
/// One store per directory per process: the store reads a file once and keeps it in memory after.
public actor OHLCVHistoryFileStore<MarketName: Hashable & Sendable & CustomStringConvertible>: OHLCVHistoryStore {
    /// The directory the files are in
    public let directory: URL

    private var loaded: [String: OHLCVHistory] = [:]

    public init(directory: URL) {
        self.directory = directory
    }

    /// The file that holds the market's history at the interval
    public nonisolated func fileURL(market: MarketName, interval: BarInterval) -> URL {
        directory.appendingPathComponent("\(Self.fileName(market.description))_\(interval.token).jsonl")
    }

    public func lastBar(market: MarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        try history(at: fileURL(market: market, interval: interval)).bars.last
    }

    public func append(_ bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap], market: MarketName, interval: BarInterval) async throws {
        let url = fileURL(market: market, interval: interval)
        let kept = try history(at: url)

        // Each gap sits before the first bar it precedes, so the file reads in time order.
        var text = ""
        var pending = gaps[...]
        for bar in bars {
            while let gap = pending.first, gap.nextBarOpenTime.milliseconds <= bar.openTime.milliseconds {
                text += try Line.gap(gap).toJSON() + "\n"
                pending = pending.dropFirst()
            }
            text += try Line.bar(bar).toJSON() + "\n"
        }
        for gap in pending {
            text += try Line.gap(gap).toJSON() + "\n"
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))

        loaded[url.path] = OHLCVHistory(bars: kept.bars + bars, gaps: kept.gaps + gaps)
    }

    public func history(market: MarketName, interval: BarInterval) async throws -> OHLCVHistory {
        try history(at: fileURL(market: market, interval: interval))
    }

    private func history(at url: URL) throws -> OHLCVHistory {
        if let kept = loaded[url.path] {
            return kept
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return OHLCVHistory(bars: [], gaps: [])
        }

        var bars: [OHLCVClientBar] = []
        var gaps: [OHLCVHistoryGap] = []
        let text = try String(contentsOf: url, encoding: .utf8)
        // A line that does not decode, a torn last line among them, is an error and never skipped.
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let decoded: Line = try String(line).fromJSON()
            switch decoded {
            case .bar(let bar): bars.append(bar)
            case .gap(let gap): gaps.append(gap)
            }
        }
        let history = OHLCVHistory(bars: bars, gaps: gaps)
        loaded[url.path] = history
        return history
    }

    private static func fileName(_ text: String) -> String {
        var name = ""
        for byte in text.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "."):
                name.append(Character(UnicodeScalar(byte)))
            default:
                name += String(format: "%%%02X", byte)
            }
        }
        return name
    }

    // One line of the file.
    enum Line: Codable {
        case bar(OHLCVClientBar)
        case gap(OHLCVHistoryGap)

        private enum CodingKeys: String, CodingKey {
            case bar
            case gap
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let bar = try container.decodeIfPresent(OHLCVClientBar.self, forKey: .bar) {
                self = .bar(bar)
            } else {
                self = .gap(try container.decode(OHLCVHistoryGap.self, forKey: .gap))
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .bar(let bar): try container.encode(bar, forKey: .bar)
            case .gap(let gap): try container.encode(gap, forKey: .gap)
            }
        }
    }
}
