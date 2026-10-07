// CoinbaseExchangeChain+Overrides.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the rows of Coinbase's table the importer cannot state (design § 2.7).

import struct CryptoAsset.Asset

extension CoinbaseExchangeChain {
    // The rows the sources cannot state, all of Coinbase's: its public products state increments, not decimals, so
    // each row's decimals are the finest increment the recorded products answer of 2026-10-06 states.
    static let overrideRows: [Row] = [
        Row(holding: .btc, wireNames: ["BTC"], decimals: 8, symbol: "BTC", asset: .btc),
        Row(holding: .eth, wireNames: ["ETH"], decimals: 8, symbol: "ETH", asset: .eth),
        Row(holding: .usd, wireNames: ["USD"], decimals: 2, symbol: "USD", asset: .usd)
        // USDC on Coinbase is no row: the recordings state its precision only as a perpetual's price step ("0.1"),
        // so it waits for a recording that states it.
    ]
}
