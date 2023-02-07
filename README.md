# CryptoScraper

![Run unit tests](https://github.com/foscomputerservices/CryptoScraper/actions/workflows/ci.yml/badge.svg)

CryptoScraper is a package for generalizing the retrieval of information from crypto block chains.

## How To Get Started

### Swift Package Manager

CryptoScraper supports the [Swift Package Manager](https://www.swift.org/package-manager/).  To include CryptoScraper in your project add the following to your Package.swift file:

```
.package(url: "git@github.com:foscomputerservices/CryptoScraper.git", branch: "main"),
```

### API Keys

To begin api keys need to be set in order to access various services.  These keys are stored in environment variables as follows:

| Service | Environment Variable | Required |
|----------------- | ----------------- | -------- |
| [Etherscan](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics#creating-an-api-key) | ETHER_SCAN_KEY | Yes | 
| [CoinGecko](https://www.coingecko.com/en/api) | ETHER_SCAN_KEY| No | 

To begin using the framework call the initialization method to initialize the block chains with their contract data.

```swift

try await CryptoScraper.initialize()

```

## Testing

In order for testing to succeed, a test contract is needed for each chain.  These contracts can be provided in the environment as follows:

| Service | Environment Variable |
| --------------- | -------------------- |
| Ethereum | ETH_TEST_CONTRACT_ADDRESS |

## Contributing

All contributions are welcome!  Please see [CONTRIBUTING.md](https://github.com/foscomputerservices/CryptoScraper/blob/main/CONTRIBUTING.md) for more details.

## Maintainers

This project is maintained by [David Hunt](https://www.linkedin.com/in/davidhun/) owner of [FOS Computerservices, LLC](https://www.linkedin.com/company/1856731).

## License

CryptoScraper is under the MIT License.  See the [LICENSE](https://github.com/foscomputerservices/CryptoScraper/blob/main/LICENSE) file for more information.