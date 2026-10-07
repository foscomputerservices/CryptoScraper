// C32 — An OHLCV client, as the identity design amends what it hands up.
// Projected from docs/fosline-suite-protocols.md C32: "The client takes an interval as a count and a unit and an
// absolute range it does not round." and "The still-open bar: its open time and its open price so far; never a closed
// bar's stand-in". And from the design § 5.3: "A client, the candle client included, reads the exchange's names off the
// wire, asks its exchange chain's `contract(for:)`, and from then on works in the holding constants." and "Every money
// value is an `Amount` in the exchange's instance."
// Recorded answers only; never a live call.

import CryptoAsset
import CryptoOHLCV
import CryptoScraper
import Foundation
import Testing

@Suite("C32 OHLCV client")
struct C32_OHLCVClientTests {
    private let start = Date(timeIntervalSince1970: 42 * 86_400)
    private let end = Date(timeIntervalSince1970: 43 * 86_400)

    private func client() throws -> BinanceOHLCVClient {
        // invented: BinanceOHLCVClient(registry:session:) and RecordedBinance.session(answering:) — "each client takes a
        // registry at init (default `.shared`)" (§ 5.3) and "FOSFoundation's mockable session with recorded responses" (§ 8.6); neither call is declared
        try BinanceOHLCVClient(registry: AssetRegistry(AssetRegistry.libraryDeclarations),
                               session: RecordedBinance.session(answering: "klines-BTCUSDT-15m"))
    }

    // invented: BinanceMarketName.btcUSDT — "each plug-in links `CryptoOHLCV` for its exchange's one typed market name" (§ 10 of the protocols); its cases are not declared
    private let market = BinanceMarketName.btcUSDT

    // "Every money value is an `Amount` in the exchange's instance." — a bar's prices are Binance's tether per Binance's bitcoin
    @Test(.disabled("Classified 2026-10-07: no recording klines-BTCUSDT-15m (Binance's 15-minute klines; the target holds the daily and 4-hour ones); see the identity ledger")) func barPricesNameBinancesHoldings() async throws {
        let bars = try await client().ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute), from: start, through: end)
        let bar = try #require(bars.first)
        #expect(bar.close.quote == AssetInstance(BinanceHolding.usdt))
        // invented: BinanceHolding.btc — "one per holding the registry declares"; Binance's bitcoin constant is not written out
        #expect(bar.close.base == AssetInstance(BinanceHolding.btc))
    }

    // "A bar as the feed gave it" — open, high, low and close share one pair of instances
    @Test(.disabled("Classified 2026-10-07: no recording klines-BTCUSDT-15m (Binance's 15-minute klines; the target holds the daily and 4-hour ones); see the identity ledger")) func allFourPricesShareTheirInstances() async throws {
        let bars = try await client().ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute), from: start, through: end)
        for bar in bars {
            for price in [bar.open, bar.high, bar.low] {
                #expect(price.quote == bar.close.quote)
                #expect(price.base == bar.close.base)
            }
        }
    }

    // "a bar's volume is `Amount.stub(asset: Price.stub().base)`" (C7) — the volume is counted in the base holding
    @Test(.disabled("Classified 2026-10-07: no recording klines-BTCUSDT-15m (Binance's 15-minute klines; the target holds the daily and 4-hour ones); see the identity ledger")) func volumeIsInTheBaseHolding() async throws {
        let bars = try await client().ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute), from: start, through: end)
        for bar in bars {
            #expect(bar.volume.instance == bar.close.base)
        }
    }

    // "closed bars for a market over an absolute UTC range"
    @Test(.disabled("Classified 2026-10-07: no recording klines-BTCUSDT-15m (Binance's 15-minute klines; the target holds the daily and 4-hour ones); see the identity ledger")) func historyBarsAreClosedAndInRange() async throws {
        let bars = try await client().ohlcv(market: market, interval: BarInterval(count: 15, unit: .minute), from: start, through: end)
        for bar in bars {
            #expect(bar.isClosed)
            #expect(bar.openTime >= start)
            #expect(bar.openTime <= end)
            #expect(bar.closeTime > bar.openTime)
        }
    }

    // "`openOHLCV` returns `isClosed == false`" (§ 8.6)
    @Test func openBarIsNotClosed() async throws {
        // invented: RecordedBinance.session(answering:) — as above
        let open = try BinanceOHLCVClient(registry: AssetRegistry(AssetRegistry.libraryDeclarations),
                                          session: RecordedBinance.session(answering: "klines-BTCUSDT-1d-open"))
        let bar = try await open.openOHLCV(market: market, interval: BarInterval(count: 1, unit: .day))
        #expect(bar?.isClosed == false)
    }

    // "each client takes a registry at init" — and "At its init each client adds its exchange's declarations to its registry"
    @Test func initAddsBinancesDeclarations() throws {
        let registry = try AssetRegistry([])
        // invented: as above
        _ = try BinanceOHLCVClient(registry: registry, session: RecordedBinance.session(answering: "klines-BTCUSDT-15m"))
        #expect(try registry.decimals(of: AssetInstance(BinanceHolding.usdt)) == 8)
    }

    // "Where one value must agree with another, the default says so through the nested stub" (C7) — the bar's stub
    @Test func barStubAgrees() {
        let bar = OHLCVClientBar.stub()
        #expect(bar.volume.instance == bar.close.base)
        #expect(bar.open.base == bar.close.base)
    }
}
