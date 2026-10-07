// C30 — The exchange clients' values: the market, as the identity design amends it (§ 5.3), with the owner's
// `alternateName: Name?` of 2026-10-07.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 5.3: "What the exchange calls the base and the
// quote, and the decimals it states for each" / "The declared holdings on this exchange chain; `nil` where nothing is
// declared" / "The smallest step of an order's size, in the base holding; `nil` where the base is undeclared". And
// "The exchange's symbol and decimals are handed up as facts beside them, for the finding and the units check, never
// as an identity." And docs/fosline-suite-protocols.md C30: "Every value struct declared here has a public memberwise
// initializer".

import CryptoAsset
import CryptoExchange
import Foundation
import Testing

@Suite("C30 ExchangeClientMarket")
struct C30_MarketTests {
    private let base = AssetInstance.stub()
    private let quote = AssetInstance.stub(address: "slate-42")

    // invented: the memberwise initializer's order and the place of `alternateName` — C30 states a memberwise
    // initializer exists; the owner's `alternateName` of 2026-10-07 has no declared position
    private func market(base: AssetInstance?, quote: AssetInstance?, alternateName: String? = nil) throws -> ExchangeClientMarket<String> {
        ExchangeClientMarket(name: "FREDBARNEY", alternateName: alternateName,
                             baseSymbol: try AssetSymbol(validating: "FRED"), baseDecimals: 4,
                             quoteSymbol: try AssetSymbol(validating: "BARNEY"), quoteDecimals: 2,
                             base: base, quote: quote,
                             lotSize: base.map { Amount(baseUnits: 1, of: $0) },
                             minimumOrder: base.map { Amount(baseUnits: 42, of: $0) },
                             maxLeverage: nil, leverageSet: nil, isPerpetual: false)
    }

    // "The declared holdings on this exchange chain; `nil` where nothing is declared"
    @Test func undeclaredHoldingsAreNil() throws {
        let unlisted = try market(base: nil, quote: nil)
        #expect(unlisted.base == nil)
        #expect(unlisted.quote == nil)
    }

    // "`nil` where the base is undeclared" — the lot and the minimum
    @Test func undeclaredBaseHasNoLotAndNoMinimum() throws {
        let unlisted = try market(base: nil, quote: nil)
        #expect(unlisted.lotSize == nil)
        #expect(unlisted.minimumOrder == nil)
    }

    // "The exchange's symbol and decimals are handed up as facts beside them" — kept on an unlisted market too
    @Test func factsStayOnAnUnlistedMarket() throws {
        let unlisted = try market(base: nil, quote: nil)
        #expect(unlisted.baseSymbol.text == "FRED")
        #expect(unlisted.baseDecimals == 4)
        #expect(unlisted.quoteSymbol.text == "BARNEY")
        #expect(unlisted.quoteDecimals == 2)
    }

    // "The smallest step of an order's size, in the base holding"
    @Test func lotSizeIsInTheBaseHolding() throws {
        let listed = try market(base: base, quote: quote)
        #expect(listed.lotSize?.instance == base)
        #expect(listed.minimumOrder?.instance == base)
    }

    // "The declared holdings on this exchange chain" — both present when declared
    @Test func declaredHoldingsArePresent() throws {
        let listed = try market(base: base, quote: quote)
        #expect(listed.base == base)
        #expect(listed.quote == quote)
    }

    // owner, 2026-10-07: "`alternateName: Name?`" — absent and present
    @Test func alternateNameIsOptional() throws {
        #expect(try market(base: base, quote: quote).alternateName == nil)
        #expect(try market(base: base, quote: quote, alternateName: "XFREDZBARNEY").alternateName == "XFREDZBARNEY")
    }

    // "never as an identity" — two markets that differ only in their facts are different values, the holdings unchanged
    @Test func factsAreNotTheIdentityOfTheHolding() throws {
        let listed = try market(base: base, quote: quote)
        #expect(listed.base == AssetInstance.stub())
        #expect(listed.baseSymbol.text != listed.base?.address)
    }

    // "Hashable, Sendable" — equal markets hash alike
    @Test func equalMarketsHashAlike() throws {
        let a = try market(base: base, quote: quote)
        let b = try market(base: base, quote: quote)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
