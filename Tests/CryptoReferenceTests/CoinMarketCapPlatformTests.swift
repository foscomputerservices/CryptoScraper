// CoinMarketCapPlatformTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoReference
import FOSFoundation
import Foundation
import Testing

// Step 5 of the identity PR (design § 5.4 item 5, § 2.4): the listing's `platform` read, against the recorded
// listing. The recording states every token address as "0x0" (a placeholder, as in the listing it was cut from), so
// these tests prove the chain; the address joins as the reference gives it.

@Suite("CoinMarketCap's platform")
struct CoinMarketCapPlatformTests {
    private func reference(_ symbols: [String]) async throws -> [ReferenceClientAsset] {
        try await CoinMarketCapClient(apiKey: "k", session: ReplaySession(route: listingRoute))
            .reference(symbols: symbols.map(symbol))
    }

    @Test(arguments: [("USDT", "825"), ("USDF", "35721")])
    func aRecordedRowOnEthereumCarriesItsInstance(symbolText: String, aggregatorId: String) async throws {
        let row = try #require(try await reference([symbolText]).first)

        #expect(row.aggregatorId == aggregatorId)
        #expect(row.platform == ReferenceClientAsset.Platform(name: "Ethereum", tokenAddress: "0x0"))
        let instance = try #require(row.instance)
        #expect(instance.chainId == EIP155.Ethereum.chainId)
        #expect(instance.address == row.platform?.tokenAddress)
    }

    @Test(arguments: [("RAIN", "Arbitrum"), ("USDC", "zkSync Era"), ("HYPE", "Hyperliquid")])
    func aRowOnAChainTheTableLacksCarriesThePlatformAndNoInstance(symbolText: String, chainName: String) async throws {
        let row = try #require(try await reference([symbolText]).first)

        #expect(row.platform?.name == chainName)
        #expect(row.instance == nil)
    }

    @Test(arguments: ["BTC", "ETH", "BNB", "XRP", "SOL", "TRX", "ZEC"])
    func aNativeCarriesNoPlatformAndNoInstance(symbolText: String) async throws {
        let row = try #require(try await reference([symbolText]).first)

        #expect(!row.aggregatorId.isEmpty)
        #expect(row.platform == nil)
        #expect(row.instance == nil)
    }

    @Test func twoRowsSharingASymbolCarryDistinctAggregatorIds() async throws {
        let memes = try await reference(["MEME"])

        #expect(memes.map(\.aggregatorId) == ["42007", "28301"])
        #expect(memes[0].platform?.name == "Robinhood Chain")
        #expect(memes[0].instance == nil)
        #expect(memes[1].platform?.name == "Ethereum")
        #expect(memes[1].instance?.chainId == EIP155.Ethereum.chainId)
    }

    @Test func aRowWithItsPlatformAndInstanceRoundTrips() async throws {
        let row = try #require(try await reference(["USDT"]).first)
        let back: ReferenceClientAsset = try row.toJSON().fromJSON()

        #expect(back == row)
        #expect(back.instance == row.instance)
    }

    @Test func thePlatformStubIsOnAChainNoTableNames() throws {
        let stub = ReferenceClientAsset.Platform.stub()
        #expect(throws: AssetRegistryError.self) {
            try AssetRegistry.chainId(named: stub.name, by: .coinMarketCap)
        }
        #expect(ReferenceClientAsset.stub().platform == nil)
        #expect(ReferenceClientAsset.stub().instance == nil)
    }
}
