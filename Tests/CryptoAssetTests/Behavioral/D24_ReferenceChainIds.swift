// D24 — The reference sources' names for a chain, mapped to CAIP-2.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.4: "The library owns one small table from each
// source's name to the chain's CAIP-2 id. Nothing else translates a source's chain name." Every source name below is
// the design's verbatim row.

import CryptoAsset
import Foundation
import Testing

@Suite("D24 Reference chain ids")
struct D24_ReferenceChainIdsTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let source: AssetReferenceSource
        let chainId: String
        var testDescription: String { "\(source) \(name)" }
    }

    // "The rows for your seven chains, each source's names taken verbatim from your aggregators' `String.chain` switches"
    static let rows: [Row] = [
        .init(name: "ethereum", source: .coinGecko, chainId: "eip155:1"),
        .init(name: "Ethereum", source: .coinMarketCap, chainId: "eip155:1"),
        .init(name: "binance-smart-chain", source: .coinGecko, chainId: "eip155:56"),
        .init(name: "BNB", source: .coinMarketCap, chainId: "eip155:56"),
        .init(name: "BNB Smart Chain (BEP20)", source: .coinMarketCap, chainId: "eip155:56"),
        .init(name: "polygon-pos", source: .coinGecko, chainId: "eip155:137"),
        .init(name: "Polygon", source: .coinMarketCap, chainId: "eip155:137"),
        .init(name: "optimistic-ethereum", source: .coinGecko, chainId: "eip155:10"),
        .init(name: "Optimism", source: .coinMarketCap, chainId: "eip155:10"),
        .init(name: "fantom", source: .coinGecko, chainId: "eip155:250"),
        .init(name: "Fantom", source: .coinMarketCap, chainId: "eip155:250"),
        .init(name: "tron", source: .coinGecko, chainId: "tron:728126428"),
        .init(name: "TRON", source: .coinMarketCap, chainId: "tron:728126428"),
        .init(name: "Tron20", source: .coinMarketCap, chainId: "tron:728126428"),
    ]

    // "each mapped to the chain's CAIP-2 id"
    @Test(arguments: rows)
    func eachRowMapsToItsChain(_ row: Row) throws {
        #expect(try AssetRegistry.chainId(named: row.name, by: row.source) == row.chainId)
    }

    // "static let referenceChainIds: [AssetReferenceSource: [String: String]]" — the table holds the same rows
    @Test(arguments: rows)
    func theTableHoldsEachRow(_ row: Row) {
        #expect(AssetRegistry.referenceChainIds[row.source]?[row.name] == row.chainId)
    }

    // "Ethereum" is CoinMarketCap's word, "ethereum" CoinGecko's: a source's name never answers for the other
    @Test func aNameIsReadOnlyBySourceItBelongsTo() {
        #expect(throws: AssetRegistryError.unknownReferenceChain("polygon-pos", by: .coinMarketCap)) {
            try AssetRegistry.chainId(named: "polygon-pos", by: .coinMarketCap)
        }
    }

    // "Bitcoin has no row: a native coin has no platform in either source."
    @Test(arguments: [AssetReferenceSource.coinGecko, .coinMarketCap])
    func bitcoinHasNoRow(_ source: AssetReferenceSource) {
        #expect(throws: AssetRegistryError.unknownReferenceChain("bitcoin", by: source)) {
            try AssetRegistry.chainId(named: "bitcoin", by: source)
        }
    }

    // "No exchange has a row: the reference sources list no exchange as a platform."
    @Test func noExchangeHasARow() {
        for table in AssetRegistry.referenceChainIds.values {
            for chainId in table.values {
                #expect(!chainId.hasPrefix("exchange:"))
            }
        }
    }

    // "Throws ``AssetRegistryError/unknownReferenceChain(_:by:)``"
    @Test func anUnknownNameThrows() {
        #expect(throws: AssetRegistryError.unknownReferenceChain("bedrock", by: .coinGecko)) {
            try AssetRegistry.chainId(named: "bedrock", by: .coinGecko)
        }
    }

    // "A row is added with its chain's conformer, in the same PR, never before." — only the seven chains' ids appear
    @Test(.disabled("Classified 2026-10-07: asserts only the seven chains have rows; the design says a row is added with its chain's conformer, in the same PR (§ 2.4), and the chains work added the conformers and their rows; see the identity ledger")) func onlyTheSevenChainsHaveRows() {
        let ids = Set(AssetRegistry.referenceChainIds.values.flatMap(\.values))
        #expect(ids.isSubset(of: ["eip155:1", "eip155:56", "eip155:137", "eip155:10", "eip155:250", "tron:728126428"]))
    }
}
