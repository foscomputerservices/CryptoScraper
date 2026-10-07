// AssetInstanceTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

// The identity's shape (design § 1.2, § 1.4, § 1.5, § 1.8): a CAIP-2 chain id and an address, split at the last
// colon, or an iso4217 code; one JSON string per instance; the self-marking stub.

@Suite("Asset instance")
struct AssetInstanceTests {
    // CAIP-2: the namespace is 3 to 8 of [-a-z0-9], the reference 1 to 32 of [-_a-zA-Z0-9]
    @Test(arguments: [
        "eip155:1:eth",
        "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "bip122:000000000019d6689c085ae165831e93:btc",
        "tron:728126428:trx",
        "exchange:kraken:XBT",
        "exchange:hyperliquid:kPEPE",
        "exchange:hyperliquid:four-hour-2x",
        "abc:1:x",
        "abcdefgh:1:x",
        "a-1:1:x",
        "eip155:a_B-9:x",
        "eip155:12345678901234567890123456789012:x"
    ])
    func aCAIP2ShapedIdIsAccepted(id: String) throws {
        let instance = try AssetInstance(validating: id)
        #expect(instance.id == id)
    }

    @Test(arguments: [
        "",
        "eth",
        "eip155:eth",
        "ab:1:x",
        "abcdefghi:1:x",
        "EIP155:1:x",
        "eip_155:1:x",
        "eip155::x",
        "eip155:123456789012345678901234567890123:x",
        "eip155:1.0:x",
        "eip155:1:",
        ":1:x",
        "iso4217:USD:x"
    ])
    func anIdOfAnyOtherShapeIsMalformed(id: String) {
        #expect(throws: AssetError.malformedIdentity(id)) {
            try AssetInstance(validating: id)
        }
    }

    @Test func theSplitReadsTheLastColon() throws {
        let token = try AssetInstance(validating: "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(token.chainId == "eip155:1")
        #expect(token.address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")

        let holding = try AssetInstance(validating: "exchange:kraken:XBT")
        #expect(holding.chainId == "exchange:kraken")
        #expect(holding.address == "XBT")

        let coin = try AssetInstance(validating: "bip122:000000000019d6689c085ae165831e93:btc")
        #expect(coin.chainId == "bip122:000000000019d6689c085ae165831e93")
        #expect(coin.address == "btc")
    }

    @Test func theDollarIsAnISO4217Code() throws {
        let usd = try AssetInstance(validating: "iso4217:USD")
        #expect(usd.id == "iso4217:USD")
        #expect(usd.chainId == nil)
        #expect(usd.address == nil)
    }

    @Test(arguments: ["iso4217:usd", "iso4217:US", "iso4217:USDT", "iso4217:", "iso4217:U5D"])
    func anISO4217CodeIsThreeCapitalLetters(id: String) {
        #expect(throws: AssetError.malformedIdentity(id)) {
            try AssetInstance(validating: id)
        }
    }

    @Test func twoInstancesAreEqualWhenTheirIdsAre() throws {
        let one = try AssetInstance(validating: "exchange:kraken:XBT")
        let other = try AssetInstance(validating: "exchange:kraken:XBT")
        #expect(one == other)
        #expect(Set([one, other]).count == 1)
        #expect(try AssetInstance(validating: "exchange:kraken:xbt") != one)
    }

    @Test func theStubIsOnTheBedrockChain() {
        let stub = AssetInstance.stub()
        #expect(stub.id == "bedrock:42:quarry-42")
        #expect(stub.chainId == "bedrock:42")
        #expect(stub.address == "quarry-42")
        #expect(!Fixtures.caipNamespaces.contains("bedrock"))
        #expect(!AssetRegistry.ownedNamespaces.contains("bedrock"))

        #expect(AssetInstance.stub(address: "pebble").id == "bedrock:42:pebble")
        #expect(AssetInstance.stub(chainId: "bedrock:7").id == "bedrock:7:quarry-42")
    }

    @Test(arguments: ["exchange:kraken:XBT", "iso4217:USD", "eip155:1:eth"])
    func anInstanceIsOneJSONString(id: String) throws {
        let instance = try AssetInstance(validating: id)
        let json = try instance.toJSON()
        #expect(json == "\"\(id)\"")

        let decoded: AssetInstance = try json.fromJSON()
        #expect(decoded == instance)
        #expect(decoded.chainId == instance.chainId)
        #expect(decoded.address == instance.address)
    }

    @Test(arguments: [#""eth""#, #""EIP155:1:x""#, #""iso4217:usd""#, #"{"id":"eip155:1:eth"}"#])
    func aMalformedIdInJSONIsADecodingError(json: String) {
        do {
            let _: AssetInstance = try json.fromJSON()
            Issue.record("decoded \(json) as an AssetInstance")
        } catch JSONError.decodingError {
            // a DecodingError, wrapped by FOSFoundation's fromJSON()
        } catch {
            Issue.record("expected a DecodingError, got \(error)")
        }
    }

    @Test func theErrorComparesByItsText() {
        #expect(AssetError.malformedIdentity("eth") == AssetError.malformedIdentity("eth"))
        #expect(AssetError.malformedIdentity("eth") != AssetError.malformedIdentity("btc"))
    }
}
