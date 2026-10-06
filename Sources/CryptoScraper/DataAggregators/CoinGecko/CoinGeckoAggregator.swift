// CoinGeckoAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// Provides standardized meta-data using [Coin Gecko's REST APIs](https://www.coingecko.com/en/api)
public final actor CoinGeckoAggregator: CryptoDataAggregator {
    public let userReadableName: String = "Coin Gecko"

    /// Returns **true** if the aggregator is configured correctly
    ///
    /// NOTE: This value has *nothing* to do with online availability.
    public static var isAvailable: Bool { apiKey != nil }

    var cachedTokensResponse: [CoinGeckoTokenResponse]?

    public init() {}
}

extension CoinGeckoAggregator {
    static let endPoint: URL = {
        if let apiKey {
            return .init(string: "https://pro-api.coingecko.com/api/v3")!
        }

        return .init(string: "https://api.coingecko.com/api/v3")!
    }()

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] }
        set { _apiKey.withLock { $0 = newValue } }
    }
}
