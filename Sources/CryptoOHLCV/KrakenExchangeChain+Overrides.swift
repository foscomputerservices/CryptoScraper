// KrakenExchangeChain+Overrides.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the rows of Kraken's table the importer cannot state (design § 2.7).

import struct CryptoAsset.Asset

extension KrakenExchangeChain {
    // The rows the sources cannot state. Kraken's dollar: CoinGecko's tickers give a fiat quote no coin id, so the
    // importer leaves ZUSD out and reports it; its decimals are Kraken's recorded Assets answer's of 2026-10-06.
    static let overrideRows: [Row] = [
        Row(holding: .usd, wireNames: ["USD", "ZUSD"], decimals: 4, symbol: "USD", asset: .usd)
    ]
}
