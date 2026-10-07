// D35 — The archived row: the instance id, the flattening the owner allows.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 3.5: "The row stores the instance id and the count.
// That is the flattening you allow: the instance is written out per row; its decimals are not." And "A price's row is its
// two instances and its scaled number (2026-10-07) ... No decimals, by the same rule." And § 6: "The row is
// `{ \"instance\": …, \"baseUnits\": … }`, decoded with no registry, `Int128.max` and `.min` included, through SQLite and
// Postgres."

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("D35 Archived rows")
struct D35_ArchivedRowTests {
    private func keys(of json: String) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return Set(try #require(object).keys)
    }

    // "{ \"instance\": \"exchange:binance:USDT\", \"baseUnits\": 12345678 }" — the design's row, decoded with no registry
    @Test func amountRowDecodesWithNoRegistry() throws {
        let row = #"{ "instance": "exchange:binance:USDT", "baseUnits": 12345678 }"#
        let amount: Amount = try row.fromJSON()
        #expect(amount.baseUnits == 12_345_678)
        #expect(amount.instance == (try AssetInstance(validating: "exchange:binance:USDT")))
    }

    // "The row stores the instance id and the count." — exactly two keys
    @Test func amountRowHasTwoKeys() throws {
        let json = try Amount(baseUnits: 42, of: .stub()).toJSON()
        #expect(try keys(of: json) == ["instance", "baseUnits"])
    }

    // "What it no longer carries: the unit names, the symbol and the exponent"
    @Test func amountRowCarriesNoUnitsSymbolOrExponent() throws {
        let json = try Amount(baseUnits: 42, of: .stub()).toJSON()
        for absent in ["unitExponent", "decimals", "symbol", "wholeUnit", "baseUnit", "units", "asset"] {
            #expect(!json.contains("\"\(absent)\""))
        }
    }

    // "the instance is written out per row" — as its id string
    @Test func amountRowsInstanceIsItsId() throws {
        let json = try Amount(baseUnits: 42, of: .stub()).toJSON()
        #expect(json.contains("\"\(AssetInstance.stub().id)\""))
    }

    // "`Int128.max` and `.min` included"
    @Test(arguments: [Int128.max, Int128.min, 0, -1])
    func amountRoundTripsAtTheExtremes(_ count: Int128) throws {
        let amount = Amount(baseUnits: count, of: .stub())
        let back: Amount = try amount.toJSON().fromJSON()
        #expect(back == amount)
    }

    // "a quoted digit string is rejected" (§ 8.1 of the protocols)
    @Test func quotedDigitStringIsRejected() {
        let row = #"{ "instance": "\#(AssetInstance.stub().id)", "baseUnits": "42" }"#
        #expect(throws: (any Error).self) { let _: Amount = try row.fromJSON() }
    }

    // "{ \"quote\": \"exchange:kraken:USD\", \"base\": \"exchange:kraken:XBT\", \"scaled\": 65000000000000 }"
    @Test func priceRowDecodesWithNoRegistry() throws {
        let row = #"{ "quote": "exchange:kraken:USD", "base": "exchange:kraken:XBT", "scaled": 65000000000000 }"#
        let price: Price = try row.fromJSON()
        #expect(price.quote == (try AssetInstance(validating: "exchange:kraken:USD")))
        #expect(price.base == (try AssetInstance(validating: "exchange:kraken:XBT")))
        #expect(price.scaled == 65_000_000_000_000)
    }

    // "A price's row is its two instances and its scaled number" — exactly three keys
    @Test func priceRowHasThreeKeys() throws {
        let row = #"{ "quote": "exchange:kraken:USD", "base": "exchange:kraken:XBT", "scaled": 65000000000000 }"#
        let price: Price = try row.fromJSON()
        #expect(try keys(of: price.toJSON()) == ["quote", "base", "scaled"])
    }

    // "round-tripped the same way" — at the extremes
    @Test(arguments: [Int128.max, Int128.min])
    func priceRoundTripsAtTheExtremes(_ scaled: Int128) throws {
        let row = #"{ "quote": "\#(AssetInstance.stub().id)", "base": "\#(AssetInstance.stub(address: "slate-42").id)", "scaled": \#(scaled) }"#
        let price: Price = try row.fromJSON()
        let back: Price = try price.toJSON().fromJSON()
        #expect(back == price)
        #expect(back.scaled == scaled)
    }

    // "through SQLite and Postgres" — the amount and the price stored and read back equal to the bit
    @Test func amountAndPriceThroughSQLite() async throws {
        // invented: StoredRowHarness.sqliteRoundTrip(_:) — § 8.1 names "FOSTestingVapor's in-memory SQLite harness"; its call is not declared
        let amount = Amount(baseUnits: Int128.max, of: .stub())
        #expect(try await StoredRowHarness.sqliteRoundTrip(amount) == amount)
        let row = #"{ "quote": "\#(AssetInstance.stub().id)", "base": "\#(AssetInstance.stub(address: "slate-42").id)", "scaled": 42 }"#
        let price: Price = try row.fromJSON()
        #expect(try await StoredRowHarness.sqliteRoundTrip(price) == price)
    }

    // "and, opt-in by an environment variable, a local Postgres"
    @Test(.enabled(if: ProcessInfo.processInfo.environment["POSTGRES_URL"] != nil))
    func amountThroughPostgres() async throws {
        // invented: StoredRowHarness.postgresRoundTrip(_:) and the POSTGRES_URL variable — the opt-in's name is not stated
        let amount = Amount(baseUnits: Int128.min, of: .stub())
        #expect(try await StoredRowHarness.postgresRoundTrip(amount) == amount)
    }
}
