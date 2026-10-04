// L21Tests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing

// L21: the retrieval's bars against the POC's candle file on the same symbol, interval and range, bar for bar. The
// file is what poc/universe/fetch-binance.ts writes: [{"time":<unix seconds, bar open>,"open","high","low","close",
// "volume"}], each number a JavaScript number written by JSON.stringify. The comparison turns the Swift values into
// that decimal text and compares text with text; the file's numbers are never read as doubles into Swift.
//
// Recorded: the two recorded Binance pages against the first 1,200 candles of btcusdt-binance-1d.json (always run).
// Live, opt-in: CRYPTO_OHLCV_LIVE=1 swift test --filter L21 fetches BTCUSDT 1d, 2017-08-17 through 2017-11-24
// (100 bars), from api.binance.com (geo-blocked from US hosts) and compares with the candle file under
// CRYPTO_OHLCV_CANDLES, default "~/Repository/FOS/Trading/Daily Weekly Setup/universe/candles".

private let liveEnabled = ProcessInfo.processInfo.environment["CRYPTO_OHLCV_LIVE"] == "1"

@Suite("L21: the retrieval against fetch-binance.ts's file")
struct L21Tests {
    @Test(arguments: ContractStoreKind.allCases)
    func theRecordedPagesMatchTheCandleFileBarForBar(kind: ContractStoreKind) async throws {
        let session = ReplaySession(route: binanceRoute)
        let kept = try await withRetrieval(kind, session: session) { retrieval in
            _ = try await retrieval.retrieve(from: Recorded.rangeStart, through: Recorded.rangeEnd, interval: Binance.day)
            return try await retrieval.history(Binance.day)
        }
        let file = try candleTexts(Recorded.l21Candles)
        #expect(file.count == 1200)
        expectSame(kept.bars, file)
    }

    @Test(.enabled(if: liveEnabled))
    func theLiveFeedMatchesTheCandleFileOnABoundedRange() async throws {
        let candles = ProcessInfo.processInfo.environment["CRYPTO_OHLCV_CANDLES"]
            ?? NSString(string: "~/Repository/FOS/Trading/Daily Weekly Setup/universe/candles").expandingTildeInPath
        let fileData = try Data(contentsOf: URL(fileURLWithPath: candles).appendingPathComponent("btcusdt-binance-1d.json"))
        let file = try Array(candleTexts(fileData).prefix(100))

        let store = OHLCVHistoryFileStore<BinanceMarketName>(directory: temporaryDirectory())
        let retrieval = OHLCVHistoryRetrieval(client: BinanceOHLCVClient(), store: store)
        _ = try await retrieval.retrieve(
            market: Binance.btcusdt, interval: Binance.day,
            from: Date(milliseconds: 1_502_928_000_000), through: Date(milliseconds: 1_502_928_000_000 + 99 * 86_400_000)
        )
        let kept = try await store.history(market: Binance.btcusdt, interval: Binance.day)
        #expect(kept.bars.count == 100)
        expectSame(kept.bars, file)
    }

    // The file's tokens, as text: [time, open, high, low, close, volume] per candle, in the file's order.
    private func candleTexts(_ data: Data) throws -> [[String]] {
        let text = String(decoding: data, as: UTF8.self)
        guard text.hasPrefix("[{"), text.hasSuffix("}]") else { throw CocoaError(.fileReadCorruptFile) }
        return text.dropFirst(2).dropLast(2).components(separatedBy: "},{").map { object in
            let fields = Dictionary(uniqueKeysWithValues: object.split(separator: ",").map { pair in
                let parts = pair.split(separator: ":", maxSplits: 1)
                return (parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"")), plainDecimal(String(parts[1])))
            })
            return ["time", "open", "high", "low", "close", "volume"].map { fields[$0] ?? "?" }
        }
    }

    // JavaScript writes a number below 1e-6 in exponent form; that text is shifted, as text, into plain decimals.
    private func plainDecimal(_ token: String) -> String {
        guard let e = token.firstIndex(where: { $0 == "e" || $0 == "E" }) else { return token }
        let exponent = Int(token[token.index(after: e)...])!
        let mantissa = String(token[..<e])
        let negative = mantissa.hasPrefix("-")
        let unsigned = negative ? String(mantissa.dropFirst()) : mantissa
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        var digits = String(parts[0]) + (parts.count > 1 ? String(parts[1]) : "")
        var point = parts[0].count + exponent
        if point <= 0 {
            digits = String(repeating: "0", count: -point + 1) + digits
            point = 1
        }
        while digits.count < point { digits += "0" }
        let result = strippedText(String(digits.prefix(point)) + "." + String(digits.dropFirst(point)))
        return negative ? "-" + result : result
    }

    private func expectSame(_ bars: [OHLCVClientBar], _ file: [[String]]) {
        #expect(bars.count == file.count)
        var mismatches = 0
        for (bar, candle) in zip(bars, file) {
            let swift = [String(bar.openTime.milliseconds / 1000)]
                + [bar.open, bar.high, bar.low, bar.close].map(decimalText)
                + [decimalText(bar.volume)]
            if swift != candle {
                mismatches += 1
                Issue.record("bar \(candle[0]): Swift \(swift) against the file \(candle)")
            }
        }
        #expect(mismatches == 0)
    }
}
