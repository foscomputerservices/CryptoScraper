// CoinGeckoAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Provides standardized meta-data using [Coin Gecko's REST APIs](https://www.coingecko.com/en/api)
public struct CoinGeckoAggregator: CryptoDataAggregator {
    public let userReadableName: String = "Coin Gecko"

    /// Returns **true** if the aggregator is configured correctly
    ///
    /// NOTE: This value has *nothing* to do with online availability.
    public static var isAvailable: Bool { apiKey != nil }

    public init() {}
}

extension CoinGeckoAggregator {
    static let endPoint: URL = {
        if let apiKey {
            return .init(string: "https://pro-api.coingecko.com/api/v3")!
        }

        return .init(string: "http://api.coingecko.com/api/v3")!
    }()

    private static var _apiKey: String?
    static var apiKey: String? {
        get { _apiKey ?? ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] }
        set { _apiKey = newValue }
    }
}
