# Getting Started with CryptoScraper

## Overview

### Library Initialization

#### Scanner Configuration

To initialize the library, first the scanners that you would like to use must be configured with your API keys.  You can specify the API keys via the Swift Environment, or directly through ``EthereumScanner``.apiKey

```swift
Etherscan.apiKey = "<my Etherscan API key>"
PolygonScan.apiKey = "<my PolygonScan API key>"
```

#### Crypto Data Aggregator Configuration

Once all needed scanners have been configured, a ``CryptoDataAggregator``'s API key must be specified.  Again, this can be specified via the Swift Environment, or directly through the aggregator's properties:

```swift
CoinGeckoAggregator.apiKey = "<my CoinGecko API key>"
```

#### Initialize the Library

The final initialization step is to initialize the library.  This will perform a one-time load of token infromation via the ``CryptoDataAggregator``.

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

The balance will be in ``CryptoAmount``.  See the documentation on that protocol for more information.

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
