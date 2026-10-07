// D53 — What the Coinbase client hands up (C30 as amended).
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 5.3: "Coinbase's `base_increment` fills `lotSize` and
// states nothing about decimals; Coinbase's balances state the holding's." And § 3.3: "`exchange:coinbase:USD` at 2".
// And § 2.7: "Coinbase's decimals (its public products state increments, not decimals; a private balances answer
// states them)" stay hand-written. And "A name the table lacks gives a market with `nil` holdings".
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoCoinbase
import CryptoExchange
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("D53 Coinbase client")
struct D53_CoinbaseClientTests {
    // invented: CoinbaseClient(credential:session:registry:), CoinbaseCredential.stub(), RecordedCoinbase.session(answering:) —
    // the initializer's labels and the recording loader are not declared
    private func client(_ recording: String, registry: AssetRegistry? = nil) throws -> CoinbaseClient {
        try CoinbaseClient(credential: .stub(), session: RecordedCoinbase.session(answering: recording),
                           registry: registry ?? AssetRegistry(AssetRegistry.libraryDeclarations))
    }

    // invented: CoinbaseHolding.usd and .btc — "one per holding the registry declares"; Coinbase's constants are not written out
    private let usd = AssetInstance(CoinbaseHolding.usd)
    private let btc = AssetInstance(CoinbaseHolding.btc)

    // "`exchange:coinbase:USD` at 2"
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func coinbaseDollarAtTwo() throws {
        #expect(try AssetRegistry(AssetRegistry.libraryDeclarations).decimals(of: usd) == 2)
        #expect(usd.id == "exchange:coinbase:USD")
    }

    // "Coinbase's `base_increment` fills `lotSize`"
    @Test func baseIncrementFillsTheLot() async throws {
        let markets = try await client("products").markets()
        let btcusd = try #require(markets.first { $0.base == btc && $0.quote == usd })
        let lot = try #require(btcusd.lotSize)
        #expect(lot.instance == btc)
        #expect(lot.baseUnits > 0)
    }

    // "and states nothing about decimals" — the lot does not move the declared decimals
    @Test(.disabled("Classified 2026-10-07: asserts the exchange holdings are among the library's declarations (§ 1.7 as first written); the design, amended 2026-10-07, says they are each exchange's own declarations, added to the registry by its clients at init, not library declarations (§ 1.7), and this test's registry is the library's declarations alone; see the identity ledger")) func incrementDoesNotChangeTheDeclaredDecimals() async throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let before = try registry.decimals(of: usd)
        _ = try await client("products", registry: registry).markets()
        #expect(try registry.decimals(of: usd) == before)
    }

    // "Coinbase's balances state the holding's" — the units check reads them
    @Test(.disabled("Classified 2026-10-07: needs CoinbaseClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; see the identity ledger")) func unitsCheckReadsTheBalances() async throws {
        // invented: CoinbaseClient.unitsCheck() -> [ExchangeUnitsFinding] — no member is declared
        #expect(try await client("accounts").unitsCheck().isEmpty)
    }

    // "Any difference is a finding" — the balances state the dollar at another precision
    @Test(.disabled("Classified 2026-10-07: needs CoinbaseClient.unitsCheck() -> [ExchangeUnitsFinding], not declared: the units check is inside markets(), which throws AssetRegistryError.decimalsChanged when the exchange states other decimals; and no recording accounts-USD-at-4; see the identity ledger")) func unitsCheckRaisesAFinding() async throws {
        // invented: as above; ExchangeUnitsFinding(instance:stated:declared:)
        let findings = try await client("accounts-USD-at-4").unitsCheck()
        #expect(findings.contains { $0.instance == usd && $0.stated == 4 && $0.declared == 2 })
    }

    // "A name the table lacks gives a market with `nil` holdings"
    @Test(.disabled("Classified 2026-10-07: no recording products-unlisted (a product whose base no table row names); see the identity ledger")) func unlistedProductGivesNilHoldings() async throws {
        let markets = try await client("products-unlisted").markets()
        let unlisted = try #require(markets.first { $0.base == nil })
        #expect(unlisted.lotSize == nil)
        #expect(unlisted.minimumOrder == nil)
    }

    // "every wire name ... resolves through `contract(for:)` to a declared holding ... none minted"
    @Test func everyListedHoldingIsOnCoinbasesChain() async throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let markets = try await client("products", registry: registry).markets()
        for instance in markets.flatMap({ [$0.base, $0.quote] }).compactMap({ $0 }) {
            #expect(instance.chainId == CoinbaseExchangeChain.default.id)
            _ = try registry.decimals(of: instance)
        }
    }

    // "A Coinbase portfolio's uuid likewise" is an address on the chain — an account, not an instance
    @Test func aPortfolioIsAnAccount() throws {
        let portfolio = AssetInstance(CoinbaseHolding(address: "quarry-42"))
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(throws: AssetRegistryError.undeclaredInstance(portfolio)) { try registry.asset(of: portfolio) }
    }

    // "Every money value is an `Amount` in the exchange's instance."
    @Test(.disabled("Classified 2026-10-07: asserts the state of portfolio quarry-42 is read; the client refuses a portfolio other than the key's own (the client gaps' 7b, built at your word 2026-10-07); see the identity ledger")) func balanceIsInCoinbasesDollar() async throws {
        let state = try await client("accounts").accountState(account: "quarry-42")
        #expect(state.balance.instance == usd)
    }

    // "At its init each client adds its exchange's declarations to its registry" and "registers the chain"
    @Test func initAddsDeclarationsAndRegistersTheChain() throws {
        let registry = try AssetRegistry([])
        _ = try client("products", registry: registry)
        #expect(try registry.decimals(of: usd) == 2)
        #expect((BlockChains.contract(of: usd) as? CoinbaseHolding) == CoinbaseHolding.usd)
    }
}
