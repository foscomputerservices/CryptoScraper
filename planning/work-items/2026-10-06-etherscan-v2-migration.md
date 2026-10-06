---
status: open
opened: 2026-10-06
origin: the FOSLine suite's step 3, layer A (CryptoScraper PR #22); the owner's word: "Create work items to bring this up-to-date or remove services that no longer are supported"
---

# The five Etherscan-family scanners move to Etherscan API V2, or go

## What is wrong

The old library's scanners call five V1 endpoints, each with its own key: `api.etherscan.io/api`, `api.bscscan.com/api`, `api.polygonscan.com/api`, `api.ftmscan.com/api`, `api-optimistic.etherscan.io/api`. On 2026-10-06:

- Etherscan answers every V1 call with `{"status":"0","message":"NOTOK","result":"You are using a deprecated V1 endpoint, switch to Etherscan API V2 using https://docs.etherscan.io/v2-migration"}`.
- BscScan's API answers `301 Moved Permanently` to `https://docs.etherscan.io/v2-migration`, which is why the tests saw `text/html`: the family's chain explorers have folded into Etherscan's one V2 API.
- PolygonScan, FTMScan and Optimistic Etherscan are the same family and follow.

In `CryptoScraperTests`, 24 of 36 XCTest cases fail for these reasons, identically before and after the Swift 6 move of 2026-10-06 (23cc8b2). CI runs that step with `continue-on-error` until this item is done.

## Done means

- One Etherscan V2 client (`https://api.etherscan.io/v2/api?chainid=<id>&…`) with one key, serving Ethereum (1), BNB Smart Chain (56), Polygon (137), Fantom (250) and Optimism (10); the five scanner types become thin per-chain configurations over it, or are removed where the owner no longer wants the chain.
- The five `_apiKey` holders collapse to one, set once (the `Mutex` holder of 23cc8b2).
- The recorded-response tests of the old target rewritten against V2's shapes; the network tests behind an opt-in as the new libraries do; `continue-on-error` removed from the step.
- A chain the owner drops is deleted with its tests, named in the change log.

## Not decided

Which chains stay. The owner's word on each before deletion.
