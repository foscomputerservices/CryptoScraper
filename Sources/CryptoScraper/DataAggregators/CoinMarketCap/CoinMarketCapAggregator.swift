// CoinMarketCapAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// Provides standardized meta-data using [Coin Market Cap's REST API](https://coinmarketcap.com/api)
public final actor CoinMarketCapAggregator: CryptoDataAggregator {
    public let userReadableName: String = "CoinMarketCap"

    /// Returns **true** if the aggregator is configured correctly
    ///
    /// NOTE: This value has *nothing* to do with online availability.
    public static var isAvailable: Bool { apiKey != nil }

    var cachedMapResponse: CurrencyMapResponse?

    public init() {}
}

extension CoinMarketCapAggregator {
    static let endPoint: URL = .init(string: "https://pro-api.coinmarketcap.com")!

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment["COIN_MARKETCAP_KEY"] }
        set { _apiKey.withLock { $0 = newValue } }
    }
}
