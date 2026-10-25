# Changelog

Every change a consumer of CryptoScraper can see, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html): before 1.0, a breaking change takes a minor version and anything else a patch.

Each pull request adds its entry under the version it will be released as, dated, so the tag goes on its own merge commit; **Unreleased** holds only what is merged and not yet given a version. The GitHub release notes repeat the version's section.

## [Unreleased]

## [0.15.1] - 2026-10-25

The owner's accounts, as the exchange lists them, so a move's side can be named. PR #40.

### Added

- `accounts()` on `ExchangeClient`: the owner's accounts the key reaches, each an `ExchangeClientAccount` with the exchange's own `id` (the text a ledger side's `account` carries and an `account` parameter takes) and the `name` the exchange gives it, `nil` where it gives none. The default implementation throws `notOffered(member: "accounts")`, so an existing conformer still compiles. A consumer names a `subAccountTransfer`'s other side by matching the side's account to an id here; the names were resolved privately before.
- **Hyperliquid:** the main wallet the key is the agent of (`userRole`), by its address with no name, then each sub-account of `subAccounts`, by its address (lower-cased) with its name, in Hyperliquid's order.
- **Coinbase:** List Portfolios, each portfolio by its uuid with its name, in Coinbase's order; the documentation states the call "retrieves all portfolios of a user", a deleted one included as listed. The key's own account reads still answer for its portfolio alone.
- **Kraken:** `notOffered`; subaccounts are institutional-only ("currently only available to institutional clients") with no listing endpoint.

## [0.15.0] - 2026-10-25

The wallet a ledger item is on, the account and wallet on each side of a move, and a position's margin kind, through every client. PR #39.

### Changed

- **Breaking:** `internalMove`'s `from` and `to` are each an `ExchangeClientLedgerSide`, the account the exchange names on that side (`nil` where it names none, the side being the account read) and the wallet on it (`ExchangeClientWallet`: `perpetuals`, `spot`, or `named` in the exchange's own word; `nil` where it states none), in place of two strings. The case's arity is unchanged.
- **Breaking:** `fill`, `deposit` and `withdrawal` each gain `wallet: ExchangeClientWallet? = nil`, last: the wallet a fill traded from, a deposit landed on or a withdrawal left, as the exchange states it. A positional pattern over each case needs one more `_`. A consumer lists a perpetuals statement from the items whose wallet is `perpetuals`, never by the market alone.
- **Hyperliquid:** a spot fill (its `coin` a spot pair's name, `@index` or `PURR/USDC`; mainnet lists both forms beside the perpetuals' coins, probed 2026-10-25) is passed over, not handed up: the client declares no spot token, and the first such fill used to refuse the whole ledger read of any wallet that ever traded spot (`unknownMarket`). The perpetuals fills read with `wallet: .perpetuals`; a perpetual in an undeclared coin still refuses the read.
- **Hyperliquid:** a `spotTransfer` update, the older spot send between two accounts (mainnet, 2026-10-25: 2141 of them against 130 `send`s among 24 users), is read as a move on the spot wallet at both ends, USDC only, as a `send` is.

### Added

- `ExchangeClientWallet` and `ExchangeClientLedgerSide` on `CryptoExchange`.
- **Hyperliquid:** a deposit's and a withdrawal's wallet is `perpetuals` (the bridge credits and debits the perpetuals USDC; the documentation: "deposits and Spot to Perp transfers will go toward collateral for those open positions"). A move's sides as the update's kind states them: `internalTransfer` and `subAccountTransfer` name `user` and `destination` on `perpetuals` (the exchange endpoint's `usdSend` and `subAccountTransfer`, beside its `spotSend` and `subAccountSpotTransfer`; mainnet, 2026-10-25: an account whose only update is one inbound `internalTransfer` of 100 with fee 1 holds 99 on perpetuals and no spot USDC. On testnet, a faucet `internalTransfer` was observed to land on spot, by the account's own statement arithmetic: a testnet observation, not coded to); `send` names both with its `sourceDex` and `destinationDex` (`""` the perpetuals dex, `"spot"`, a builder dex as `named`); `accountClassTransfer` names no account, its sides the one account's `spot` and `perpetuals` by `toPerp`. A `send` within one account now names the account on both sides, where it named only the dexes.
- **Kraken:** a fill's wallet is `spot`; a deposit's and a withdrawal's is `nil` (the entry states none). A transfer's sides name no account and take their wallets from the subtype as Kraken's ledger fields documentation lists them: `spottofutures`/`spotfromfutures` between `spot` and `perpetuals`, `spottostaking`/`stakingfromspot`/`stakingtospot`/`spotfromstaking` between `spot` and `named("staking")`, `allocation`/`deallocation` between `spot` and `named("earn")`; any other subtype states no wallet. The former `from: subtype, to: asset` placeholder is gone.
- **Coinbase:** a fill's wallet is `perpetuals` where its product is a perpetual future (`contract_expiry_type` "PERPETUAL"), `spot` otherwise.
- `ExchangeClientPosition` gains `marginKind: ExchangeClientMarginKind?` (`cross` or `isolated`), last and defaulting to `nil`: how the exchange margins the position, as it states it.
- **Hyperliquid:** a position's `marginKind` is its `leverage.type`, "cross" or "isolated"; `nil` for any other word.
- **Kraken** and **Coinbase:** `nil`; neither states one.

## [0.14.0] - 2026-10-24

A fill's own id, the account's fee rates, and a position's open profit and held margin, through every client. PR #38.

### Changed

- **Breaking:** `ExchangeClient` gains an associated type, `FillId`, the exchange's own id for a fill, and `ExchangeClientLedgerItem` a fifth generic parameter for it, after the order id: `ExchangeClientLedgerItem<Name, OrderId, FillId, TransferId, Cursor>`. A conformer adds `typealias FillId`.
- **Breaking:** `fill` carries `id: FillId`, required, after `order:`: two fills of one order, or of one transaction, differ by it, and a consumer names the fill's postings by it (the owner's ruling of 2026-10-24). A positional pattern over the case needs one more `_`. A fill the exchange lists without one is refused, the whole read with it. A funding item has no id of its own: its identity is its cursor, the exchange naming it by its time and market alone (Hyperliquid's funding `hash` is all zeros on mainnet, probed 2026-10-24).
- **Hyperliquid:** `HyperliquidFillId`, the fill's `tid`. Several fills share one transaction `hash` (mainnet, 2026-10-24: 2000 fills, 1761 hashes, 2000 trade ids).
- **Kraken:** `KrakenFillId`, the trade's own key in TradesHistory, the transaction id its Ledgers entries refer to.
- **Coinbase:** `FillId` is `CoinbaseTradeId`, the fill's `trade_id`, the id the cursor already names it by.
- **Kraken:** a fill's `fee` is its Ledgers entry's in the pair's quote, the amount the balance moved by at the ledger's four places. Kraken states the trade's own `fee` at the pair's `cost_decimals` (5 on XBT/USD, 2 to 12 by pair on the dollar pairs, live 2026-10-24), finer than the dollar's four, and a real fill's fee was refused; the trade's own figure is read only where the ledger read holds no entry for the trade (the owner's ruling of 2026-10-24: the dollar stays at Kraken's ledger scale, four).

### Added

- `feeRates(account:)` on `ExchangeClient`: the rates the exchange applies to the account's trades, each an `ExchangeClientFeeRate` with `maker`, `taker` (fractions: 0.00045 is 4.5 basis points) and the `scope` the exchange states it for: `account`, `perpetuals`, `spot`, or `market(Name)`. The default implementation throws `notOffered(member: "feeRates")`, so an existing conformer still compiles.
- **Hyperliquid:** `userFees`: the perpetuals pair (`userAddRate` maker, `userCrossRate` taker) then the spot pair (`userSpotAddRate`, `userSpotCrossRate`), discounts included as the documentation states ("include any active discounts from referrals or staking").
- **Kraken:** one TradeVolume call naming every pair of AssetPairs: each pair's `fees` entry as the taker rate and its `fees_maker` entry as the maker rate, or the one `fees` rate where Kraken states no maker schedule; Kraken's percentages ("0.2600") read as fractions (0.0026). One rate per market.
- **Coinbase:** Get Transaction Summary's fee tier, `maker_fee_rate` and `taker_fee_rate`, one pair for the whole account.
- `ExchangeClientPosition` gains `openProfit: Amount?` and `heldMargin: Amount?`, last and defaulting to `nil`: the position's unrealized profit and the margin the exchange holds for it, as stated, `nil` where the exchange states none.
- **Hyperliquid:** a position's `openProfit` is its `unrealizedPnl` and its `heldMargin` its `marginUsed`, in USDC. The account value fosline asked for is `balance`, already `marginSummary.accountValue`.
- **Kraken:** a position's `openProfit` is its `net` (`docalcs`; a gain's leading "+" dropped) and its `heldMargin` its `margin`, in the pair's quote; `nil` where Kraken states the figure finer than the quote holding's places, the figure being Kraken's estimate that moves no balance: neither rounded nor refused.
- **Coinbase:** no positions, so neither field.

### Fixed

- **Kraken:** a fill whose fee Kraken states with a fifth decimal was refused (`belowBaseUnit`), the whole ledger read with it; the recorded fixture's zero fee hid it. The fee now comes from the ledger entry, at four.

## [0.13.0] - 2026-10-20

The Hyperliquid ledger read to the end, and a folded funding day's payment count. PR #35.

### Changed

- **Breaking:** `ExchangeClientLedgerItem.funding` carries `payments: Int? = nil`, last: the number of payments the exchange states the item sums, where it hands up a summary in place of the payments; `nil` where it states no count, the item being one payment. A consumer tells a summary by this, never by the item's time. A positional pattern over the case needs one more `_`; constructing a funding item without it is unchanged.
- **Hyperliquid:** `ledgerItems` walks each of its three windowed reads (`userFillsByTime`, `userFunding`, `userNonFundingLedgerUpdates`) page by page to the end. Hyperliquid's documentation: "Responses that take a time range will only return 500 elements or distinct blocks of data. To query larger ranges, use the last returned timestamp as the next `startTime` for pagination"; `userFillsByTime` "returns at most 2000 fills per response". A page shorter than the cap is the last; a full page is followed from its last item's time, the window being inclusive, and the items already held at that time are dropped. Confirmed on mainnet, 2026-10-20: a `userFunding` from 0 answered 500 of an account's 969 items, and from the 500th's time the other 469.
- **Hyperliquid:** a funding item's `payments` is the exchange's `nSamples`. Funding older than about a week Hyperliquid hands up folded, one item per market per day stamped at the day's 00:00:00.000 UTC summing the day's payments, `nSamples` their number (1 to 24 observed); a payment carries null, so `nil`. Observed on mainnet and testnet alike, 2026-10-20; the documentation lists `nSamples` without stating the fold.

### Fixed

- **Hyperliquid:** a ledger read from the start, or from an old cursor, on an account with more than 500 funding items (or 2000 fills, or 500 other updates) stopped at the exchange's cap with no sign that more existed; the newest days were missing.

## [0.12.0] - 2026-10-19

A movement's own id, required. PR #34.

### Changed

- **Breaking:** `ExchangeClient` gains an associated type, `TransferId`, the exchange's own id for a movement of money, and `ExchangeClientLedgerItem` a fourth generic parameter for it: `ExchangeClientLedgerItem<Name, OrderId, TransferId, Cursor>`. A conformer adds `typealias TransferId`.
- **Breaking:** `deposit`, `withdrawal` and `internalMove` each carry `id: TransferId`, required, after the amount (after `to:` on a move). A fee charged on a movement, or a later read of it, names it by this id, as a fill's fee names its order (the owner's ruling of 2026-10-19). A positional pattern over the three cases needs one more `_`.
- An item the exchange lists without its id is refused (`malformedResponse`), the whole read with it, never handed up without one.
- **Hyperliquid:** `HyperliquidTransferId`, the update's `hash` (`0x` and 64 hex digits; all zeros refused). A move between the main account and a sub-account carries the same hash in both ledgers.
- **Kraken:** `KrakenTransferId`, the Ledgers entry's `refid`, the reference Kraken's deposit and withdrawal status reads name the movement by. The entry's own key stays a `KrakenLedgerId`, in the cursor.
- **Coinbase:** `CoinbaseTransferId`, declared for the protocol; the client hands up no movement, so none is made.
- The CryptoOHLCV exchange transactions (`HyperliquidTransaction`, `KrakenTransaction`, `CoinbaseTransaction`) take a movement's transfer id as their `hash` and `transactionId`, where they took its cursor.

## [0.11.0] - 2026-10-19

Hyperliquid's USDC at eight decimals. PR #33.

### Changed

- **Breaking:** `HyperliquidHolding.usdc` is declared at 8 decimals, not 6. One token, two books: Hyperliquid states USDC at six places on its perpetuals book (an account's value, a fill's fee, a funding payment, a transfer) and at eight on its spot book (`spotMeta`'s `szDecimals` and `weiDecimals`, a spot balance). The holding takes the finer, so every figure the exchange states in it is representable and none is refused for being finer than the declaration (the owner's ruling of 2026-10-19).
- **Migrate stored values:** the holding's base unit is now a hundred-millionth of a dollar, so every Hyperliquid USDC `Amount` stored as base units at six must be multiplied by 100. A stored `Price` quoted in Hyperliquid's USDC scales the same way. Values read fresh from the exchange need nothing.
- A six-place figure reads exactly at eight. Perpetuals orders are unchanged: a limit and a size go out as the same decimal text, and a size is in the base coin's holding.
- A market's `quoteDecimals` is 8, and a book's `quoteVolume` keeps eight places of the turnover where it kept six.
- **Hyperliquid:** `transfer` sends Hyperliquid's millionths, the holding's base units over 100. An amount finer than a millionth is refused, never rounded, and nothing is sent.
- **Hyperliquid:** `holdings(account:)` reads every spot USDC balance at its eight places; one finer than eight is refused.

## [0.10.0] - 2026-10-19

An account's wallet, read through every client. PR #31.

### Added

- `holdings(account:)` on `ExchangeClient`: each holding the exchange lists for the account, by the exchange's own name, as an `ExchangeClientHolding` with its `total` and the part `held`. A holding the exchange's table declares none for is listed by its name, with `instance`, `total` and `held` `nil`. The default implementation throws `notOffered(member: "holdings")`, so an existing conformer still compiles.
- **Hyperliquid:** the spot balances from `spotClearinghouseState`. Token 0, USDC, is read in the USDC holding the perpetuals' value counts in; a total finer than its six places is refused, never rounded. Other spot tokens are listed by name with no amount. The account's money is `accountState`'s `balance` (the perpetuals) plus its spot USDC.
- **Kraken:** the wallet from `BalanceEx`, `balance` as the total and `hold_trade` as the held part.
- **Coinbase:** the key's portfolio's wallets, available plus held as the total, each wallet once.

## [0.9.0] - 2026-10-19

A deposit's, a withdrawal's and a move's fee, as the exchange states it. PR #29.

### Changed

- **Breaking:** `ExchangeClientLedgerItem`'s `deposit`, `withdrawal` and `internalMove` each carry `fee: Amount? = nil`, last. A positional pattern over the three cases needs one more `_`; constructing an item without a fee is unchanged.
- The fee is the one the exchange states on the item, in the holding it states it in. `nil` where it states none; a stated zero is a zero amount. The amount beside it is the exchange's own figure, never netted against the fee.
- **Hyperliquid:** `fee` is read in USDC on `internalTransfer`, `send`, `withdraw`, and on a `subAccountTransfer` that carries one.
- **Hyperliquid:** a `send` within one account is a move between its dexes, `"spot"` and `"perp"` (the wire's `""`). Between accounts, it is a move between their addresses, as before.
- **Kraken:** each `Ledgers` entry's `fee`, in the entry's asset, on deposits, withdrawals and transfers.

### Fixed

- **Hyperliquid:** a `send` of a token other than USDC, or one with its fee in another token, was read as a USDC amount. It is no longer handed up.

## [0.8.1] - 2026-10-09

Five more Hyperliquid holdings. PR #27.

### Added

- **Hyperliquid:** DOGE, SAND, NEO, RUNE and ALGO declared in the table at the `szDecimals` both networks' `meta` state, each in its class by the library's declarations.
- An opt-in live test that reads `meta` on both networks.

## [0.8.0] - 2026-10-09

Which holdings stand for a currency. PR #26.

### Added

- `CurrencyDeclaration(currency:holdings:)` in the registry: a holding it names is accepted where the currency is named, one for one, with no conversion and no rate.
- `AssetRegistry.holding(standingFor:on:)`, the one holding on an exchange chain that stands for a currency; none or two is a typed finding.
- `AssetRegistry.currency(of:)`, the currency a holding stands for.
- Declared for `iso4217:USD`: Binance's USDT and USDC, Hyperliquid's USDC, Kraken's ZUSD and Coinbase's USD.

## [0.7.0] - 2026-10-08

The localization library, lowercase EVM addresses, and ledger cursors that name their item. PR #25.

### Added

- **CryptoAssetLocalization**, a new library: `LocalizableAmount`, `LocalizablePrice` and `LocalizableFraction`, rendering the exact integer in the reader's locale through FOSMVVM's localizing encoder, never through a `Double`.

### Changed

- **Breaking:** an `eip155` address is lowercased at validation, by `AssetInstance(validating:)` and `Asset(validating:)`. A stored id with a mixed-case address decodes to the lowercase one. Other namespaces keep their address as given.
- `KrakenLedgerCursor` and `CoinbaseLedgerCursor` carry the instant plus the exchange's own ids read at it (`KrakenLedgerId`, `CoinbaseTradeId`), so a read hands up every item once, a second item at the cursor's instant included. They encode as objects; an old bare-time cursor still decodes, as naming no item.

## [0.6.1] - 2026-10-07

A CoinGecko demo key, and an importer that writes no classless rows. PR #24.

### Added

- `COIN_GECKO_DEMO_KEY`: a demo key on CoinGecko's free endpoint, sent in the `x-cg-demo-api-key` header. `COIN_GECKO_KEY` is still a pro key on the pro endpoint and wins where both are set.

### Changed

- The generated declarations are the top-1000 import of 2026-10-07: 715 asset classes; Binance's table 283 rows, Kraken's 330.

### Fixed

- The importer wrote exchange rows for listed names with no class, so a table resolved a wire name to a holding nothing declares. Each such name is now a `noClass` finding, and a market in it is listed with `nil` holdings.

## [0.6.0] - 2026-10-07

Asset identity: an asset is no longer a symbol. PR #23.

### Added

- `AssetInstance`: one contract on one chain, one holding on one exchange, or a fiat, named by its CAIP-2 chain id and its address, or an ISO 4217 code.
- `Asset`, the class of instances that are one asset, keyed by its home instance; `AssetDeclaration` states a class once, with its names, its units and each instance's decimals and symbol.
- `AssetRegistry`, the one statement of declarations. `AssetRegistry.shared` holds the library's declarations and the generated ones (`Assets.all`); each exchange client adds its holdings at its init; a disagreeing statement is refused.
- 54 chains admitted, each with its CAIP-2 id, its native declared, its address rule in `contract(for:)` and its scanner as the oracle of its decimals. The eleven EVM chains share Etherscan API V2 and one key.
- The four exchanges as chains in the `exchange` namespace, their holdings as constants and their wire names in one table.
- `Scripts/import-assets.swift`, the importer that writes the `+Imported.swift` declarations from CoinGecko and the exchanges' listings.
- **CryptoFearGreed**, a new library: the public Fear and Greed client.
- **CryptoReference** hands up a listing's platform.
- CI builds CryptoAsset for iOS, tvOS and watchOS.

### Changed

- **Breaking:** an asset is named by its instance. `Asset.btc` and the like remain, as classes; a symbol is a fact of an instance, never a key.
- **Breaking:** `Amount` and `Price` count in an instance's base units, resolved through a registry; an undeclared instance throws `AssetRegistryError.undeclaredInstance`.
- **Breaking:** C30's market hands up its holdings (`nil` where undeclared), the exchange's symbols and decimals as facts, its lot and minimum as optional amounts, and `alternateName`.
- **Breaking:** C31's `placeOrder` takes `clientOrderId: UInt128?` before `account:`; an open order carries `clientOrderId`.
- **Breaking:** each client takes `registry: AssetRegistry = .shared` as its last parameter.
- **Breaking:** five scanners are no longer optional; an unconfigured scanner throws, never a zero.
- Hyperliquid's ledger cursor carries its place, and its markets their leverage set; Coinbase reads only the key's own portfolio.
- `BlockChains` is public, for `contract(of:)` and `register(_:)`.
- USD Coin's token name is CoinGecko's, "USDC".

### Removed

- Web3, which was unused.

## Before 0.6.0

`v0.1.0` to `v0.5.0` were tagged without release notes; their history is the git log.

[Unreleased]: https://github.com/foscomputerservices/CryptoScraper/compare/0.12.0...HEAD
[0.12.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.12.0
[0.11.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.11.0
[0.10.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.10.0
[0.9.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.9.0
[0.8.1]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.8.1
[0.8.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.8.0
[0.7.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.7.0
[0.6.1]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.6.1
[0.6.0]: https://github.com/foscomputerservices/CryptoScraper/releases/tag/0.6.0
