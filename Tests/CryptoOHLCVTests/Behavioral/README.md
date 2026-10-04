# Layer A2 — the behavioral suite of the public OHLCV and reference clients

Projected on 2026-10-04 from the requirements alone (layer-a2-inputs.md): C32, C33, § 7's head, § 8.6, the step-2 brief's § 5.1 and layer A, OQ-S20, directions D11, D13, D16, D17, T8, T9, T10, T69, T87, L17 and C1–C8. No implementation was seen.

## How to run it

Copy the folder into the CryptoScraper package's test target that links `CryptoAsset`, `CryptoOHLCV` and `CryptoReference`, add the builder's adapter file (the functions listed in BehavioralAssumptions.md), and run `swift test` from the package root. The suite is Swift Testing; every test is red until the surface and the adapters exist.

The suite needs no network and no database: the Binance and CoinMarketCap answers are scripted in BehavioralFixtures.swift, and the file store writes under the temporary directory, which the tests never remove.

## How a red test is classified

- **no surface member** — the invented signature has no real member to map onto. The builder adds the member or records why not.
- **weak construction** — the test or its adapter is built wrongly (a fixture's shape, a fake's behaviour, a compile error in the test's own code). The fixture or the fake is corrected; the assertion is not.
- **a reading of a silence in the documents** — the test is marked `// READING:` and `(READING)` in its name, and the silence it named is decided the other way. The owner rules on the silence; the test follows the ruling.
- **spec against the documents** — the implementation contradicts what a keyed text says. The implementation is fixed.

## The behaviours, by key

**C32 — the protocol** (C32_OHLCVClient.swift, 4): a conformer of the two declared members satisfies it; the Binance conformer is one, reachable generically; both are Sendable; the market name is Hashable and Sendable.

**C32 — the bar** (C32_OHLCVClientBar.swift, 6): nine properties of the declared types; nine stored values; no `String` property; the stub's volume in its prices' base asset; the stub overrides only what it is given; Hashable.

**C32, § 1, § 8.6 — the Binance conformer** (C32_BinanceConformer.swift, 14): recorded klines decode exactly; `"65000.00"` and `"0.00012500"` exact; a price beyond the quote's base unit and a price below one base unit exact; no `String` handed up; a malformed number throws `AmountError.malformedText`; (READING) too many digits throw `AmountError.belowBaseUnit`; `{"code": -1121}` decodes into the typed error; (READING) a 429 is a typed limit with its `Retry-After`; the request's market, interval token and range; each `BarInterval` sent as its token (7 cases); `openOHLCV` hands up the open bar with `isClosed == false`; (READING) nil when no bar is open.

**§ 5.1 — paging** (Retrieval_Paging.swift, 7): more than one request; every bar once, in order; each page boundary bar once; cursors increase; same market and interval on every page; values exact across pages; the report matches the store.

**§ 5.1, T10 — gaps** (Retrieval_Gaps.swift, 9): one missing bar is one gap bounded by its neighbours; the gap is kept in the store; never filled; neighbours kept; a 300-bar gap kept and not judged; two gaps in order; a gap on a page boundary; (READING) a late-starting series records no leading gap; a daily gap.

**§ 5.1 — the limit** (Retrieval_Limit.swift, 7): sleeps exactly the `Retry-After`; resends the same cursor; a mid-paging limit resumes that page with nothing dropped or doubled; two limits are two back-offs; a limit is not thrown; no limit, no sleep; (READING) no `Retry-After` backs off once for a positive default.

**§ 5.1, OQ-S20 — resume** (Retrieval_Resume.swift, 6): the second fetch starts at the kept last bar; adds only newer bars; the store holds the range once; nothing newer adds nothing; a gap across the resume is kept; a reopened file store resumes.

**§ 5.1, OQ-S20, D17 — the store** (Retrieval_Store.swift, 14; 9 of them run on both conformers): empty reads empty; kept reads back value for value; a second keep adds; exact values and millisecond times survive; (READING) out-of-order keeps read back in order; (READING) a double keep reads once; series separate by market and interval; gaps read back; the retrieval behaves alike on both conformers; the file store conforms; survives a reopen; two directories are two stores; D17: the retrieval runs on the file store alone; (READING) the file store writes only in its directory.

**C33, D13 — the reference client** (C33_ReferenceClient.swift, 11): a conformer of the one member; CoinMarketCapClient conforms and is Sendable; the value's four typed properties; its stub and Hashable; symbols and names from the recorded response; only the symbols asked; a non-empty sector; (READING) tiers keep the ranks' order; (READING) an unlisted symbol left out; `error_code` 1002 becomes the typed error; (READING) an error envelope under HTTP 200 is still the typed error.

**D16 — the range and the interval** (D16_RangeUnrounded.swift, 7): `ohlcv`, `openOHLCV` and `fetch` take `BarInterval` and `Date` and nothing else; `BarInterval` encodes as count and unit; (READING) a misaligned start passed unchanged and not rejected; the end passed unchanged; the retrieval's first cursor is the start unchanged.

**T8, T69, T9 — closed bars only** (T8_T69_ClosedBarsOnly.swift, 5): the open bar left out of `ohlcv`; every bar closed; the `openOHLCV` bar never among the closed; the retrieval never keeps the open bar; nor records it as a gap.

**T87 — UTC instants** (T87_UTCInstants.swift, 5): open and close times the feed's milliseconds; the daily opens at 00:00 UTC; unchanged under a far process time zone; the weekly bar unrounded; instants survive the file store.

**§ 7's head, L17, C33 — facts, not decisions** (L17_FactsNotDecisions.swift, 5): a zero-volume bar handed up; a stablecoin handed up; a rank-4000 asset handed up; assets with no chain platform handed up; (READING) the tier is the API's rank and the sector one of its tags, no bucket invented.

C33's declared `sector: String` and `tier: Int` and the READING on the rank and tags may not both pass; that is for the classification.
