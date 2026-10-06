---
status: open
opened: 2026-10-06
origin: the FOSLine suite's step 3, layer A (CryptoScraper PR #22); the owner's word: "Create work items to bring this up-to-date or remove services that no longer are supported"
---

# CoinGecko and CoinMarketCap return fewer tokens than the old tests expect

## What is wrong

`CryptoScraperTests` asserts token counts above fixed floors (for example more than 250) for each chain's token list from CoinGecko and CoinMarketCap; on 2026-10-06 the services return fewer (136 in one case). The code did not change; the services' lists, their paging or their free-tier limits did. The same cases failed before the Swift 6 move (23cc8b2).

## Done means

- Each aggregator's token-list endpoint re-read against the service's current documentation: paging, plan limits, and whether the `tokens(for:)` contract of `CryptoDataAggregator` still means what it did.
- The tests assert what the service documents, from a recorded response, with the live call behind an opt-in; or the aggregator is removed if the owner no longer wants it.
- `continue-on-error` removed from the old aggregators' CI step together with the Etherscan V2 item.

## Not decided

Whether both aggregators stay; the owner's word.
