// ExchangeChainRowsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoOHLCV
import Testing

// Design § 2.7, the files: an exchange chain's table is the union of the rows the importer generates and the rows
// written by hand for what the sources cannot state; a wire name in both is refused.

@Suite("An exchange chain's table: the imported rows and the overrides")
struct ExchangeChainRowsTests {
    @Test func noWireNameOfKrakensIsBothImportedAndOverridden() {
        let imported = Set(KrakenExchangeChain.importedRows.flatMap(\.wireNames))
        let overridden = Set(KrakenExchangeChain.overrideRows.flatMap(\.wireNames))

        #expect(imported.isDisjoint(with: overridden))
    }

    @Test func noWireNameOfBinancesIsBothImportedAndOverridden() {
        let imported = Set(BinanceExchangeChain.importedRows.flatMap(\.wireNames))
        let overridden = Set(BinanceExchangeChain.overrideRows.flatMap(\.wireNames))

        #expect(imported.isDisjoint(with: overridden))
    }

    @Test func krakensTableIsItsImportedRowsAndItsOverrides() {
        #expect(KrakenExchangeChain.rows.map(\.holding) == (KrakenExchangeChain.importedRows + KrakenExchangeChain.overrideRows).map(\.holding))
        // The imported set grew with the top-1000 run of 2026-10-07; the three the recording states are in it still
        #expect(Set(KrakenExchangeChain.importedRows.map(\.holding)).isSuperset(of: [.xbt, .eth, .sol]))
        #expect(KrakenExchangeChain.overrideRows.map(\.holding) == [.usd])
    }

    @Test func binancesTableIsItsImportedRowsAndNoOverride() {
        #expect(BinanceExchangeChain.rows.map(\.holding) == BinanceExchangeChain.importedRows.map(\.holding))
        // The imported set grew with the top-1000 run of 2026-10-07; the two the recording states are in it still
        #expect(Set(BinanceExchangeChain.importedRows.map(\.holding)).isSuperset(of: [.btc, .usdt]))
        #expect(BinanceExchangeChain.overrideRows.isEmpty)
    }

    @Test func hyperliquidsAndCoinbasesTablesAreTheirOverridesAlone() {
        #expect(HyperliquidExchangeChain.rows.map(\.holding) == HyperliquidExchangeChain.overrideRows.map(\.holding))
        #expect(CoinbaseExchangeChain.rows.map(\.holding) == CoinbaseExchangeChain.overrideRows.map(\.holding))
    }
}
