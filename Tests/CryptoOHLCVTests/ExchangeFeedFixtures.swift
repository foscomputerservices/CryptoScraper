// ExchangeFeedFixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The Hyperliquid, Kraken and Coinbase recordings under Resources/<Exchange>/ were made on 2026-10-06 between 07:49
// and 07:56 UTC from this Mac, read-only, public endpoints only. Each file's first line is a `//` header naming the
// request and the time; the replay serves the body below it, untouched.

enum Feed {
    // The body of a recording, its `//` header lines and the recorder's one closing newline dropped.
    static func body(_ path: String) -> Data {
        let text = String(decoding: Recorded.data(path), as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).drop { $0.hasPrefix("//") }
        if lines.last == "" { lines = lines.dropLast() }
        return Data(lines.joined(separator: "\n").utf8)
    }

    // The raw number texts of a JSON body at a key path, as the exchange sent them.
    static func json(_ path: String) -> Any {
        try! JSONSerialization.jsonObject(with: body(path))
    }

    // The instants of the recordings.
    static let hyperliquidRecordedAt = Date(timeIntervalSince1970: 1_791_272_942)   // 2026-10-06T07:49:02Z
    static let krakenRecordedAt = Date(timeIntervalSince1970: 1_791_272_956)        // 2026-10-06T07:49:16Z, the OHLC
    static let coinbaseRecordedAt = Date(timeIntervalSince1970: 1_791_273_346)      // 2026-10-06T07:55:46Z, the 4h latest

    static let fourHours = BarInterval(count: 4, unit: .hour)
    static let day = BarInterval(count: 1, unit: .day)
}

// A number's text with its trailing fraction zeros stripped, through the package's one parse.
func normalized(_ text: String) -> String {
    try! WireDecimal(parsing: text).text
}

// A price's or an amount's exact decimal text, through the package's one way out.
func wireText(_ price: Price) -> String { WireDecimal(price).text }
func wireText(_ amount: Amount) -> String { WireDecimal(amount).text }

extension URLRequest {
    // The request's JSON body, for a POST.
    var jsonBody: [String: Any] {
        guard let body = httpBody else { return [:] }
        return (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
    }
}
