# Changelog

Every change a consumer of CryptoScraper can see, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html): before 1.0, a breaking change takes a minor version and anything else a patch.

Each pull request adds its entry under the version it will be released as, dated, so the tag goes on its own merge commit; **Unreleased** holds only what is merged and not yet given a version. The GitHub release notes repeat the version's section.

## [Unreleased]

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
