// CoinGeckoAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// Provides standardized meta-data using [Coin Gecko's REST APIs](https://www.coingecko.com/en/api)
///
/// Without a key it asks the free endpoint. A key, read from the environment variable `COIN_GECKO_KEY`, selects the
/// pro endpoint and travels in the `x-cg-pro-api-key` header. A demo key is not supported: it would be sent to the
/// pro endpoint in the pro header.
public final actor CoinGeckoAggregator: CryptoDataAggregator {
    public let userReadableName: String = "Coin Gecko"

    /// Returns **true** if the aggregator is configured correctly: a key is set, which selects the pro endpoint
    ///
    /// NOTE: This value has *nothing* to do with online availability. **false** does not stop the aggregator; it
    /// asks the free endpoint.
    public static var isAvailable: Bool { apiKey != nil }

    var cachedTokensResponse: [CoinGeckoTokenResponse]?

    public init() {}
}

extension CoinGeckoAggregator {
    /// The pro endpoint when a key is set, the free endpoint without one; read at each request, so a key set after
    /// the first request is used
    static var endPoint: URL {
        apiKey == nil ? freeEndPoint : proEndPoint
    }

    static let proEndPoint = URL(string: "https://pro-api.coingecko.com/api/v3")!
    static let freeEndPoint = URL(string: "https://api.coingecko.com/api/v3")!

    /// The header every request carries the key in: `x-cg-pro-api-key`, the pro endpoint's, which a set key selects
    /// (CoinGecko's authentication documentation); `nil` without a key
    static func headers() -> [(field: String, value: String)]? {
        apiKey.map { [(field: "x-cg-pro-api-key", value: $0)] }
    }

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] }
        set { _apiKey.withLock { $0 = newValue } }
    }
}
