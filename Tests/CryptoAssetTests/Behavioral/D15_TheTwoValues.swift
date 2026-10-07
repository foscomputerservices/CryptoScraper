// D15 — The two values CryptoAsset carries: AssetInstance and Asset.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.5: "One contract on one chain, one holding on
// one exchange, or a fiat, as CryptoScraper's `CryptoContract.id` states it" and "Two instances are equal when their
// ids are" and "The encoded shape of each is its id alone, one JSON string." and "The ':' split reads the last colon."

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("D15 AssetInstance and Asset")
struct D15_TheTwoValuesTests {
    // "`chain.id + \":\" + address`" — the doc's token literal "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    @Test func tokenIdSplitsIntoChainAndAddress() throws {
        let usdc = try AssetInstance(validating: "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(usdc.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(usdc.chainId == "eip155:1")
        #expect(usdc.address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
    }

    // "The chain's or exchange's id, the part before the last ':'" — the doc's literal "exchange:binance:USDT"
    @Test func exchangeHoldingSplitsAtTheLastColon() throws {
        let usdt = try AssetInstance(validating: "exchange:binance:USDT")
        #expect(usdt.chainId == "exchange:binance")
        #expect(usdt.address == "USDT")
    }

    // "The ':' split reads the last colon." — the doc's literal "bip122:000000000019d6689c085ae165831e93:btc"
    @Test func nativeCoinSplitsAtTheLastColon() throws {
        let btc = try AssetInstance(validating: "bip122:000000000019d6689c085ae165831e93:btc")
        #expect(btc.chainId == "bip122:000000000019d6689c085ae165831e93")
        #expect(btc.address == "btc")
    }

    // "`nil` for a fiat" — the doc's literal "iso4217:USD"
    @Test func fiatHasNoChainAndNoAddress() throws {
        let usd = try AssetInstance(validating: "iso4217:USD")
        #expect(usd.id == "iso4217:USD")
        #expect(usd.chainId == nil)
        #expect(usd.address == nil)
    }

    // "Throws malformedIdentity when `id` is not a CAIP-2-shaped chain id and an address, or an `iso4217` code"
    // The inputs below are malformed on purpose: no colon, a chain id with no address, an empty string.
    @Test(arguments: ["", "quarry", "eip155:1", ":quarry-42", "bedrock:42:"])
    func malformedIdThrows(_ id: String) {
        #expect(throws: AssetError.malformedIdentity(id)) { try AssetInstance(validating: id) }
    }

    // "Two instances are equal when their ids are"
    @Test func equalWhenIdsAreEqual() throws {
        let one = try AssetInstance(validating: "exchange:kraken:XBT")
        let two = try AssetInstance(validating: "exchange:kraken:XBT")
        #expect(one == two)
        #expect(one.hashValue == two.hashValue)
    }

    // "Two instances are equal when their ids are" — the converse
    @Test func differentIdsDiffer() throws {
        #expect(try AssetInstance(validating: "exchange:kraken:USD") != AssetInstance(validating: "iso4217:USD"))
    }

    // "The encoded shape of each is its id alone, one JSON string."
    @Test func instanceEncodesAsOneString() throws {
        let usdt = try AssetInstance(validating: "exchange:binance:USDT")
        #expect(try usdt.toJSON() == "\"exchange:binance:USDT\"")
    }

    // "or decoded from a stored row" — the round trip
    @Test func instanceRoundTrips() throws {
        let usdt = try AssetInstance(validating: "exchange:binance:USDT")
        let back: AssetInstance = try usdt.toJSON().fromJSON()
        #expect(back == usdt)
    }

    // "The class's key: its home instance's id"
    @Test func assetIdIsItsHomeInstancesId() throws {
        let asset = try Asset(validating: "eip155:1:eth")
        #expect(asset.id == "eip155:1:eth")
    }

    // "public init(validating id: String) throws" on Asset
    @Test func assetMalformedIdThrows() {
        #expect(throws: AssetError.malformedIdentity("quarry")) { try Asset(validating: "quarry") }
    }

    // "The encoded shape of each is its id alone, one JSON string." — Asset
    @Test func assetEncodesAsOneString() throws {
        let asset = try Asset(validating: "iso4217:USD")
        #expect(try asset.toJSON() == "\"iso4217:USD\"")
        let back: Asset = try asset.toJSON().fromJSON()
        #expect(back == asset)
    }

    // "Two instances are one asset when the map puts them in one class." — an Asset is not an instance's id by equality of symbol
    @Test func assetEqualityIsById() throws {
        #expect(try Asset(validating: "eip155:1:eth") == Asset(validating: "eip155:1:eth"))
        #expect(try Asset(validating: "eip155:1:eth") != Asset(validating: "eip155:10:eth"))
    }

    // "`eip155:1:eth`. Optimism's is `eip155:10:eth`, a different instance of the same asset" (§ 1.2)
    @Test func sameAddressOnTwoChainsAreTwoInstances() throws {
        #expect(try AssetInstance(validating: "eip155:1:eth") != AssetInstance(validating: "eip155:10:eth"))
    }
}
