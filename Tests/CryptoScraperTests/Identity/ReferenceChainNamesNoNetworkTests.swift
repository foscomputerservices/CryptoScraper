// ReferenceChainNamesNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import Foundation
import Testing

/// Design § 2.4 and § 6 "The aggregator's rows land on it": the reference source's platform names reach a chain
/// through `AssetRegistry.referenceChainIds` alone, in place of the 2023 `String.chain` switches. A recorded-shape
/// answer decoded in place; no network.
@Suite struct ReferenceChainNamesNoNetworkTests {
    @Test func coinMarketCapsRowsLandOnTheirChains() throws {
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(Self.listing.utf8))

        let bsc = try response.tokens(for: BNBContract.self)
        #expect(bsc.map(\.contractAddress.address) == ["0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"])

        let polygon = try response.tokens(for: MaticContract.self)
        #expect(polygon.map(\.contractAddress.address) == ["0x3c499c542cef5e3811e1192ce70d8cc03d5c3359"])

        let tron = try response.tokens(for: TronContract.self)
        #expect(tron.map(\.contractAddress.address) == ["TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"])
    }

    @Test func aPlatformTheTableLacksLandsNowhere() throws {
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(Self.listing.utf8))
        #expect(try response.tokens(for: EthereumContract.self).isEmpty)
        #expect(try response.tokens(for: FantomContract.self).isEmpty)
        #expect(try response.tokens(for: OptimismContract.self).isEmpty)
    }

    // Four rows in CoinMarketCap's map shape: two names for BNB Smart Chain's and Polygon's platforms the table holds,
    // Tron's TRC-20 name, and Solana, which the table lacks. Addresses as the aggregator gives them, mixed case.
    private static let listing = """
    {
      "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                  "elapsed": 1, "credit_count": 1 },
      "data": [
        { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
          "first_historical_data": "2018-10-08T00:00:00.000Z",
          "platform": { "id": 1839, "name": "BNB Smart Chain (BEP20)", "symbol": "BNB", "slug": "bnb",
                        "token_address": "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d" } },
        { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
          "first_historical_data": "2018-10-08T00:00:00.000Z",
          "platform": { "id": 3890, "name": "Polygon", "symbol": "POL", "slug": "polygon",
                        "token_address": "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359" } },
        { "id": 825, "name": "Tether USDt", "symbol": "USDT", "slug": "tether", "is_active": 1,
          "first_historical_data": "2015-02-25T00:00:00.000Z",
          "platform": { "id": 1958, "name": "Tron20", "symbol": "TRX", "slug": "tron",
                        "token_address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t" } },
        { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
          "first_historical_data": "2018-10-08T00:00:00.000Z",
          "platform": { "id": 5426, "name": "Solana", "symbol": "SOL", "slug": "solana",
                        "token_address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v" } }
      ]
    }
    """
}
