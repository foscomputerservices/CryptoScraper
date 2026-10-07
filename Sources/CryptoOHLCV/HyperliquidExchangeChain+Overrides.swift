// HyperliquidExchangeChain+Overrides.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the rows of Hyperliquid's table the importer cannot state (design § 2.7).

import struct CryptoAsset.Asset
import struct CryptoAsset.AssetDeclaration
import enum CryptoAsset.EIP155
import enum CryptoAsset.SOLANA
import enum CryptoAsset.TRON

extension HyperliquidExchangeChain {
    // The rows the sources cannot state, all of Hyperliquid's: CoinGecko's tickers read answers no ticker for
    // Hyperliquid (recorded 2026-10-07: its perpetuals are under CoinGecko's derivatives), and no meta lists USDC.
    static let overrideRows: [Row] = [
        Row(holding: .btc, wireNames: ["BTC"], decimals: 5, symbol: "BTC", asset: .btc),
        Row(holding: .eth, wireNames: ["ETH"], decimals: 4, symbol: "ETH", asset: .eth),
        Row(holding: .usdc, wireNames: ["USDC"], decimals: 6, symbol: "USDC", asset: .usdc),
        // Solana's coin, in Solana's class (the recorded `meta` states SOL at 2 size decimals).
        Row(holding: .sol, wireNames: ["SOL"], decimals: 2, symbol: "SOL", asset: classOf(SOLANA.Solana.sol)),
        // A thousand PEPE: the map is one-to-one, so kPEPE joins no class until a scale is designed (design § 7.2).
        Row(holding: .kPEPE, wireNames: ["kPEPE"], decimals: 0, symbol: "kPEPE", asset: nil),
        // The chains' coins whose classes the library declares (step 3), at the size decimals the recorded mainnet
        // `meta` states (the testnet recording states BNB and POL alike and lists no TRX).
        Row(holding: .bnb, wireNames: ["BNB"], decimals: 3, symbol: "BNB", asset: classOf(EIP155.BinanceSmartChain.bnb)),
        Row(holding: .pol, wireNames: ["POL"], decimals: 0, symbol: "POL", asset: classOf(EIP155.Polygon.pol)),
        Row(holding: .trx, wireNames: ["TRX"], decimals: 0, symbol: "TRX", asset: classOf(TRON.Tron.trx))
    ]

    // The class a library-declared home instance keys: the asset whose id is the home's.
    private static func classOf(_ home: AssetDeclaration.Instance) -> Asset {
        try! Asset(validating: home.instance.id)
    }
}
