// ReferenceChainIdsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// Design § 2.4: each reference source's names for a chain, taken verbatim from the aggregators' `String.chain`
// switches, each mapped to the chain's CAIP-2 id. Tron's id is the decimal form the namespace registers.

@Suite("Reference chain names")
struct ReferenceChainIdsTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let source: AssetReferenceSource
        let chainId: String
        var testDescription: String {
            "\(source) \"\(name)\" → \(chainId)"
        }
    }

    static let rows: [Row] = [
        Row(name: "ethereum", source: .coinGecko, chainId: "eip155:1"),
        Row(name: "Ethereum", source: .coinMarketCap, chainId: "eip155:1"),
        Row(name: "binance-smart-chain", source: .coinGecko, chainId: "eip155:56"),
        Row(name: "BNB", source: .coinMarketCap, chainId: "eip155:56"),
        Row(name: "BNB Smart Chain (BEP20)", source: .coinMarketCap, chainId: "eip155:56"),
        Row(name: "polygon-pos", source: .coinGecko, chainId: "eip155:137"),
        Row(name: "Polygon", source: .coinMarketCap, chainId: "eip155:137"),
        Row(name: "optimistic-ethereum", source: .coinGecko, chainId: "eip155:10"),
        Row(name: "Optimism", source: .coinMarketCap, chainId: "eip155:10"),
        Row(name: "fantom", source: .coinGecko, chainId: "eip155:250"),
        Row(name: "Fantom", source: .coinMarketCap, chainId: "eip155:250"),
        Row(name: "tron", source: .coinGecko, chainId: "tron:728126428"),
        Row(name: "TRON", source: .coinMarketCap, chainId: "tron:728126428"),
        Row(name: "Tron20", source: .coinMarketCap, chainId: "tron:728126428"),
        // The EVM chains admitted with Etherscan V2 (2026-10-07): CoinGecko's ids from its asset platforms, CoinMarketCap's
        // names from its recorded listing, which names no platform for Ethereum Classic, Theta or COTI
        Row(name: "avalanche", source: .coinGecko, chainId: "eip155:43114"),
        Row(name: "Avalanche C-Chain", source: .coinMarketCap, chainId: "eip155:43114"),
        Row(name: "ethereum-classic", source: .coinGecko, chainId: "eip155:61"),
        Row(name: "celo", source: .coinGecko, chainId: "eip155:42220"),
        Row(name: "Celo", source: .coinMarketCap, chainId: "eip155:42220"),
        Row(name: "base", source: .coinGecko, chainId: "eip155:8453"),
        Row(name: "Base", source: .coinMarketCap, chainId: "eip155:8453"),
        Row(name: "theta", source: .coinGecko, chainId: "eip155:361"),
        Row(name: "coti", source: .coinGecko, chainId: "eip155:2632500"),
        // The chains in their own namespaces (2026-10-07): CoinGecko's ids from its asset platforms, CoinMarketCap's
        // names from its recorded listing, which names a platform for Solana and Neo alone of these
        Row(name: "solana", source: .coinGecko, chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"),
        Row(name: "Solana", source: .coinMarketCap, chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"),
        Row(name: "xrp", source: .coinGecko, chainId: "xrpl:0"),
        Row(name: "stellar", source: .coinGecko, chainId: "stellar:pubnet"),
        Row(name: "tezos", source: .coinGecko, chainId: "tezos:NetXdQprcVkpaWU"),
        Row(name: "algorand", source: .coinGecko, chainId: "algorand:wGHE2Pwdvd7S12BL5FaOP20EGYesN73k"),
        Row(name: "hedera-hashgraph", source: .coinGecko, chainId: "hedera:mainnet"),
        Row(name: "neo", source: .coinGecko, chainId: "neo:860833102"),
        Row(name: "Neo", source: .coinMarketCap, chainId: "neo:860833102"),
        Row(name: "elrond", source: .coinGecko, chainId: "mvx:1"),
        Row(name: "stacks", source: .coinGecko, chainId: "stacks:1"),
        Row(name: "iota", source: .coinGecko, chainId: "iota:mainnet"),
        Row(name: "vechain", source: .coinGecko, chainId: "vechain:b1ac3413d346d43539627e6be7ec1b4a"),
        Row(name: "VeChain", source: .coinMarketCap, chainId: "vechain:b1ac3413d346d43539627e6be7ec1b4a"),
        Row(name: "flow", source: .coinGecko, chainId: "flow:mainnet"),
        Row(name: "qtum", source: .coinGecko, chainId: "bip122:000075aef83cf2853580f8ae8ce6f8c3"),
        Row(name: "cosmos", source: .coinGecko, chainId: "cosmos:cosmoshub-4"),
        Row(name: "thorchain", source: .coinGecko, chainId: "cosmos:thorchain-1"),
        Row(name: "terra-2", source: .coinGecko, chainId: "cosmos:phoenix-1"),
        Row(name: "near-protocol", source: .coinGecko, chainId: "near:mainnet"),
        Row(name: "cardano", source: .coinGecko, chainId: "cip34:1-764824073"),
        Row(name: "internet-computer", source: .coinGecko, chainId: "icp:mainnet"),
        Row(name: "ontology", source: .coinGecko, chainId: "ont:mainnet"),
        Row(name: "zilliqa", source: .coinGecko, chainId: "zil:mainnet"),
        Row(name: "Cardano", source: .coinMarketCap, chainId: "cip34:1-764824073")
    ]

    @Test(arguments: rows)
    func eachRowMapsToItsChain(row: Row) throws {
        #expect(try AssetRegistry.chainId(named: row.name, by: row.source) == row.chainId)
    }

    @Test func theTableHoldsTheseRowsAndNoOthers() {
        let coinGecko = Dictionary(uniqueKeysWithValues: Self.rows.filter { $0.source == .coinGecko }.map { ($0.name, $0.chainId) })
        let coinMarketCap = Dictionary(uniqueKeysWithValues: Self.rows.filter { $0.source == .coinMarketCap }.map { ($0.name, $0.chainId) })
        #expect(AssetRegistry.referenceChainIds == [.coinGecko: coinGecko, .coinMarketCap: coinMarketCap])
    }

    @Test func everyChainIdInTheTableIsCAIP2Shaped() throws {
        for chainId in AssetRegistry.referenceChainIds.values.flatMap(\.values) {
            #expect(try AssetInstance(validating: chainId + ":x").chainId == chainId)
        }
    }

    @Test(arguments: [
        Row(name: "bitcoin", source: .coinGecko, chainId: ""),
        Row(name: "aptos", source: .coinGecko, chainId: ""),
        Row(name: "Ethereum", source: .coinGecko, chainId: ""),
        Row(name: "ethereum", source: .coinMarketCap, chainId: ""),
        Row(name: "kraken", source: .coinMarketCap, chainId: "")
    ])
    func aNameTheTableLacksThrows(row: Row) {
        #expect(throws: AssetRegistryError.unknownReferenceChain(row.name, by: row.source)) {
            try AssetRegistry.chainId(named: row.name, by: row.source)
        }
    }

    @Test func theSourceRoundTripsAndStubs() throws {
        for source in [AssetReferenceSource.coinGecko, .coinMarketCap] {
            let decoded: AssetReferenceSource = try source.toJSON().fromJSON()
            #expect(decoded == source)
        }
        #expect([AssetReferenceSource.coinGecko, .coinMarketCap].contains(AssetReferenceSource.stub()))
    }
}
