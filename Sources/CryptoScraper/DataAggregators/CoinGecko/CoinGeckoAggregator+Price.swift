// CoinGeckoAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinGeckoAggregator {
    /// Returns the current price for a given ``CryptoContract`` in ``Currency``
    ///
    /// - Parameters:
    ///   - contract: The ``CryptoContract`` to look up the price for
    ///   - currency: The ``Currency`` to price the ``CryptoContract`` in
    ///
    /// - Returns: The ``Amount`` of the ``CryptoContract`` in ``Currency``
    func price<Contract: CryptoContract, C: Currency>(for contract: Contract, in currency: C) async throws -> Amount<C> {

        // https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd
        // {"bitcoin":{"usd":64289}}
        let response: CoinGeckoPriceResponse = try await Self.endPoint
            .appending(path: "simple/price")
            .appending(
                queryItems: PriceResponse.httpQuery(contract: contract, currency: currency)
            )
            .fetch(errorType: CoinGeckoError.self)

        return try response.price(of: contract, in: currency)
    }
}

private struct PriceResponse: Decodable {
    // https://www.coingecko.com/en/api/documentation
    static func httpQuery<Contract: CryptoContract, C: Currency>(contract: Contract, currency: C) throws -> [URLQueryItem] {

        guard
            let cgTokenId = contract.tokenInfo?.aggregatorId
        else {
            // TODO: If needed, add exception
            fatalError("Unable to retrieve TokenInfo aggregatorId??")
        }

        return [
            .init(name: "ids", value: cgTokenId),
            // TODO: How to do "usd"???.  We don't have an 'id' for these yet.
            .init(name: "vs_currencies", value: "usd")
        ]
    }
}

struct CoinGeckoPriceResponse: Decodable {
    let prices: [String: [String: Double]]

    fileprivate func price<Contract: CryptoContract, C: Currency>(of contract: Contract, in currency: C) throws -> Amount<C> {
        guard
            let cgTokenId = contract.tokenInfo?.aggregatorId
        else {
            // TODO: If needed, add exception
            fatalError("Unable to retrieve TokenInfo aggregator id??")
        }

        // TODO: How to do "usd"???.  We don't have an 'id' for these yet.
        guard let price = prices[cgTokenId]?["usd"] else {
            // TODO: Add a proper error response here
            fatalError("Unable to retrieve amount from response")
        }

        return Amount(quantity: price, currency: currency, units: .defaultDisplayUnits)
    }

    // MARK: Decodable
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.prices = try container.decode([String : [String : Double]].self)
    }
}
