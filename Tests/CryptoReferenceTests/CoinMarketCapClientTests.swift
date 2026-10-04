// CoinMarketCapClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoReference
import FOSFoundation
import Foundation
import Testing

// § 8.6 for the reference client, against a recorded listing: the facts read from the response (the rank and the
// tags; C33's sector and tier are the caller's reading, UNRATIFIED), the error path by errorType, and an opt-in
// live call behind CMC_PRO_API_KEY.

private let liveKey = ProcessInfo.processInfo.environment["CMC_PRO_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }

@Suite("CoinMarketCap reference client")
struct CoinMarketCapClientTests {
    @Test func theRankTheTagsAndTheCountAreReadFromTheListing() async throws {
        let session = ReplaySession(route: listingRoute)
        let assets = try await CoinMarketCapClient(apiKey: "test-key", session: session)
            .reference(symbols: [symbol("ETH"), symbol("BTC"), symbol("RAIN")])

        #expect(assets.map(\.symbol) == [symbol("BTC"), symbol("ETH"), symbol("RAIN")])
        let btc = assets[0]
        #expect(btc.name == "Bitcoin")
        #expect(btc.rank == 1)
        #expect(btc.tags.first == "mineable")
        #expect(btc.tags.contains("layer-1"))
        #expect(btc.tags.count == 37)
        #expect(btc.isCountedInMarketCap)
        #expect(assets[1].rank == 2)
        #expect(assets[2].rank == 201)
        #expect(assets[2].isCountedInMarketCap == false)
    }

    @Test func theRequestCarriesTheKeyTheEndpointAndTheAuxFields() async throws {
        let session = ReplaySession(route: listingRoute)
        _ = try await CoinMarketCapClient(apiKey: "test-key", session: session).reference(symbols: [symbol("BTC")])
        let request = try #require(session.requests.first)

        #expect(request.url!.host == "pro-api.coinmarketcap.com")
        #expect(request.url!.path == "/v1/cryptocurrency/listings/latest")
        #expect(request.value(forHTTPHeaderField: "X-CMC_PRO_API_KEY") == "test-key")
        #expect(request.query("aux") == "cmc_rank,date_added,tags,platform,is_market_cap_included_in_calc")
        #expect(request.query("start") == "1")
        #expect(request.query("limit") == "5000")
    }

    @Test func aSymbolListedTwiceIsHandedUpTwiceInRankOrder() async throws {
        let session = ReplaySession(route: listingRoute)
        let memes = try await CoinMarketCapClient(apiKey: "k", session: session).reference(symbols: [symbol("MEME")])
        #expect(memes.count == 2)
        #expect(memes[0].rank < memes[1].rank)
    }

    @Test func aListedSymbolThatIsNotWellFormedIsPassedOverWithoutFailingTheListing() async throws {
        let session = ReplaySession(route: listingRoute)
        let assets = try await CoinMarketCapClient(apiKey: "k", session: session)
            .reference(symbols: [symbol("USDF"), symbol("SOL"), symbol("NOPE")])
        // CoinMarketCap's "USDf" answers USDF (a symbol is upper-cased on the way in); 币安人生 is no AssetSymbol.
        #expect(assets.map(\.symbol) == [symbol("SOL"), symbol("USDF")])
    }

    @Test func theListingIsPagedUntilEverySymbolIsFound() async throws {
        let session = ReplaySession(route: listingRoute)
        let client = CoinMarketCapClient(apiKey: "k", session: session, pageSize: 5)

        let found = try await client.reference(symbols: [symbol("BTC"), symbol("ZEC")])
        #expect(found.map(\.rank) == [1, 10])
        #expect(session.requests.map { $0.query("start") } == ["1", "6"])
    }

    @Test func theListingIsReadToItsEndForASymbolItDoesNotList() async throws {
        let session = ReplaySession(route: listingRoute)
        let found = try await CoinMarketCapClient(apiKey: "k", session: session, pageSize: 5).reference(symbols: [symbol("NOPE")])
        #expect(found.isEmpty)
        // Three full pages of five, then the short page that ends the listing.
        #expect(session.requests.map { $0.query("start") } == ["1", "6", "11", "16"])
    }

    @Test func noSymbolsAsksNothing() async throws {
        let session = ReplaySession(route: listingRoute)
        #expect(try await CoinMarketCapClient(apiKey: "k", session: session).reference(symbols: []).isEmpty)
        #expect(session.requests.isEmpty)
    }

    @Test func anErrorEnvelopeDecodesByErrorTypeIntoCoinMarketCapsError() async throws {
        let session = ReplaySession { _ in Reply(status: 401, body: Recorded.keyMissing) }
        await #expect(throws: CoinMarketCapError(code: 1002, message: "API key missing.")) {
            try await CoinMarketCapClient(apiKey: "", session: session).reference(symbols: [symbol("BTC")])
        }
    }

    @Test func aSuccessStatusIsNeverTakenForAnError() throws {
        #expect(throws: (any Error).self) {
            let _: CoinMarketCapError = try Recorded.listings.fromJSON()
        }
    }

    @Test func theAssetStubIsTheReservedFake() throws {
        let stub = ReferenceClientAsset.stub()
        #expect(stub.symbol.text == "FRED")
        #expect(stub.rank == 42)
        #expect(ReferenceClientAsset.stub(isCountedInMarketCap: false).isCountedInMarketCap == false)
        let back: ReferenceClientAsset = try stub.toJSON().fromJSON()
        #expect(back == stub)
    }

    @Test(.enabled(if: liveKey != nil))
    func theLiveListingAnswersThreeSymbols() async throws {
        let assets = try await CoinMarketCapClient(apiKey: liveKey!, pageSize: 200)
            .reference(symbols: [symbol("BTC"), symbol("ETH"), symbol("SOL")])
        #expect(Set(assets.map(\.symbol)).isSuperset(of: [symbol("BTC"), symbol("ETH"), symbol("SOL")]))
        #expect(assets.first { $0.symbol == symbol("BTC") }?.rank == 1)
        #expect(assets.allSatisfy { !$0.tags.isEmpty })
    }
}
