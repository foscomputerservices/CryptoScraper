# Getting Started with CryptoScraper

## Overview

### Library Initialization

#### Scanner Configuration

To initialize the library, first the scanners that you would like to use must be configured with your API keys.  Every ``EthereumScanner`` asks Etherscan's API V2 with one key, Etherscan's: specify it via the environment variable `ETHER_SCAN_KEY`, or directly through ``Etherscan/apiKey``.  Setting another conformer's `apiKey`, such as `PolygonScan.apiKey`, sets that same key.

```swift
Etherscan.apiKey = "<my Etherscan API key>"      // for every EthereumScanner's chain
```

#### Crypto Data Aggregator Configuration

Once all needed scanners have been configured, a ``CryptoDataAggregator``'s API key can be specified, through the environment; the aggregators' key properties are internal to the package.

- ``CoinGeckoAggregator``: `COIN_GECKO_KEY`, optional. Without it the free endpoint is asked; with it the pro endpoint, the key in the `x-cg-pro-api-key` header. A demo key is not supported.
- ``CoinMarketCapAggregator``: `COIN_MARKETCAP_KEY`, required; without it its requests throw ``CoinMarketCapError``.

#### Initialize the Library

The final initialization step is to initialize the library.  This will perform a one-time load of token information via the ``CryptoDataAggregator``.  This will use the ``CoinGeckoAggregator`` by default.

```swift
try await CryptoScraper.initialize()
```

### Retrieving Information from Ethereum-based Scanners

#### Retrieving the balance for an account

The ``EthereumScanner`` protocol can be used to retrieve information for accounts and contracts.  To retrieve the balance for a particular account (address):

```swift
let etherScan = Etherscan()
let balance = try await etherScan.getBalance(forAccount: accountContract)
```

The balance will be in ``Amount``.  See the documentation on that type for more information.

#### Retrieving the balance of a particular coin for an account

To retrieve the balance of a coin for a particular account (address):

```swift
let etherScan = Etherscan()
let rlcToken = EthereumContract(address: "0x607F4C5BB672230e8672085532f7e901544a7375")
let balance = try await etherScan.getBalance(forToken: rlcToken, forAccount: accountContract)
```

### Retrieving the transactions for an account

To retrieve the transactions for a particular account (address):

```swift
let etherScan = Etherscan()
let transactions = try await etherScan.getTransactions(forAccount: accountContract)
```
