# Layer A2 — the invented signatures

Every signature below was invented because the one input (layer-a2-inputs.md) does not declare it. The builder maps each onto one real member through an adapter under THE WIRING RULE: an adapter may map one invented signature onto one real member; an assertion never changes.

C32's `OHLCVClient`, `OHLCVClientBar`, C33's `ReferenceClient`, `ReferenceClientAsset`, `CoinMarketCapClient`, and C1–C8 are used exactly as declared and are not listed.

## The library's surface (CryptoOHLCV), invented

- **`BinanceOHLCVClient`** — the name of C32's Binance conformer; C32 says only "Four conformers: Binance, …". Key: C32, layer A.
- **`protocol OHLCVStore: Sendable`** — the store protocol the library declares. Key: § 5.1, OQ-S20.
- **`func bars(market: String, interval: BarInterval) async throws -> [OHLCVClientBar]`** — on `OHLCVStore`, reads a series back in open-time order. Key: § 5.1 ("readable back … in order").
- **`func keep(_ bars: [OHLCVClientBar], market: String, interval: BarInterval) async throws`** — on `OHLCVStore`, keeps bars. Key: § 5.1, D17 ("fetching a history and keeping it").
- **`func gaps(market: String, interval: BarInterval) async throws -> [OHLCVGap]`** — on `OHLCVStore`, reads the kept gaps in order. Key: § 5.1 ("detected and kept").
- **`func keep(_ gaps: [OHLCVGap], market: String, interval: BarInterval) async throws`** — on `OHLCVStore`, keeps gaps. Key: § 5.1.
- **The store's series key is `market: String` plus `BarInterval`**, the market's text being the exchange's symbol ("BTCUSDT"); the retrieval derives it from the client's `MarketName`. Key: § 5.1 (the gate: "the market the client's own `MarketName`").
- **`struct OHLCVGap: Hashable, Sendable`** with **`init(after: Date, before: Date)`**, **`let after: Date`** (the open time of the last bar before the gap) and **`let before: Date`** (the open time of the first bar after it). Key: § 5.1 ("a gap is detected and kept").
- **`struct FileOHLCVStore: OHLCVStore`** with **`init(directory: URL) throws`**; a new instance on the same directory is the reopen. Key: OQ-S20, D17.
- **`struct OHLCVRetrieval<Client: OHLCVClient, Store: OHLCVStore>`** — the OHLCV retrieval. The name repeats C29's protocol in FOSTradeAssetHistory, a different module; the step-2 brief says "the OHLCV retrieval names two things". Key: § 5.1, layer A.
- **`init(client: Client, store: Store, sleep: @escaping @Sendable (Duration) async throws -> Void)`** — on `OHLCVRetrieval`; the clock for the back-off is the injected sleep the projector brief names. Key: § 5.1 ("backing off on a limit").
- **`func fetch(market: Client.MarketName, interval: BarInterval, from: Date, through: Date) async throws -> OHLCVRetrievalReport`** — on `OHLCVRetrieval`; one call both fetches a new range and resumes from what is kept. Key: § 5.1, D16.
- **`struct OHLCVRetrievalReport`** with **`let added: [OHLCVClientBar]`** (the bars this fetch newly kept, in order) and **`let gaps: [OHLCVGap]`** (the gaps this fetch newly detected, in order); `added` is compared with `==`, so it is assumed `Equatable` through its elements. Key: § 5.1.
- **`OHLCVClientBar.stub(openTime:closeTime:open:high:low:close:volume:trades:isClosed:)`** — C7's rule ("stub(…) with every parameter of the public initializer") applied to C32's nine properties; C32 declares `Stubbable` but no initializer. Key: C32, C7.
- **`ReferenceClientAsset.stub(symbol:name:sector:tier:)`** — the same rule for C33's four properties. Key: C33, C7.

## The adapter functions (the builder writes these)

- **`func behavioralBinanceClient(session: any BehavioralSession, now: @escaping @Sendable () -> Date) -> BinanceOHLCVClient`** — builds the conformer over the mocked session; `now` decides which bar is still open. Key: § 8.6 ("against FOSFoundation's mockable session"), C32 (`openOHLCV`), T8.
- **`func behavioralBinanceMarket(_ symbol: String, base: Asset, quote: Asset) -> BinanceOHLCVClient.MarketName`** — the market name for a symbol, with the market's assets in hand for the decode ("with the market's assets in hand", § 1 under C3). Key: C32, § 1.
- **`func behavioralCoinMarketCapClient(session: any BehavioralSession) -> CoinMarketCapClient`** — builds the conformer over the mocked session, with whatever key it needs. Key: C33, D13.
- **`func behavioralExchangeError(_ error: any Error) -> BehavioralExchangeError?`** — reads the code and message out of the client's typed error, or nil when the error is not that. Key: § 8.6 ("decoded by `errorType` into the client's typed error"), D13.
- **`func behavioralLimit(_ error: any Error) -> BehavioralLimit?`** — reads a limit out of the client's typed error, with the `Retry-After` it carried, or nil. Key: § 5.1 (back-off), § 8.6.

## The test-owned types (in BehavioralFixtures.swift; the builder binds, never changes)

- **`protocol BehavioralSession: Sendable { func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) }`** — the projector brief's session; the adapter binds it to FOSFoundation's mockable session. Key: § 8.6.
- **`struct BehavioralExchangeError { code: Int; message: String }`** and **`struct BehavioralLimit { retryAfter: Duration? }`** — what the two error adapters return. Key: § 8.6, § 5.1.
- **`actor BehavioralMemoryStore: OHLCVStore`** — the second conformer of the store protocol, in the test. Key: OQ-S20.
- **`actor BehavioralBinanceFeed`**, **`actor RecordedSession`**, **`actor SleepRecorder`** — the fake endpoint, the scripted session and the recorded clock.

## Behaviour assumed of the fake feed

- Binance's paging: bars with openTime ≥ `startTime` and ≤ `endTime`, ascending, at most `limit` (default 500, at most 1,000); without `startTime`, the latest `limit` bars, the still-open one last. Key: § 5.1.
- A bar is still open when its closeTime is at or after the client's `now`. Key: T8, C32.
