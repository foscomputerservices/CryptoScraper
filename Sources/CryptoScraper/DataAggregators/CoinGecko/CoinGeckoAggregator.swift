// CoinGeckoAggregator.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// Provides standardized meta-data using [Coin Gecko's REST APIs](https://www.coingecko.com/en/api)
///
/// Without a key it asks the free endpoint. A pro key, read from the environment variable `COIN_GECKO_KEY`, selects
/// the pro endpoint and travels in the `x-cg-pro-api-key` header. A demo key, read from `COIN_GECKO_DEMO_KEY`, keeps
/// the free endpoint and travels in the `x-cg-demo-api-key` header, as CoinGecko's authentication documentation has
/// it (a demo key sent to the pro endpoint is refused, error 10011). Where both are set the pro key is used.
public final actor CoinGeckoAggregator: CryptoDataAggregator {
    public let userReadableName: String = "Coin Gecko"

    /// Returns **true** if the aggregator is configured correctly: a pro or a demo key is set
    ///
    /// NOTE: This value has *nothing* to do with online availability. **false** does not stop the aggregator; it
    /// asks the free endpoint without a key.
    public static var isAvailable: Bool {
        apiKey != nil || demoApiKey != nil
    }

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

    /// The header every request carries the key in: `x-cg-pro-api-key` for a pro key, which selects the pro
    /// endpoint; `x-cg-demo-api-key` for a demo key, on the free endpoint (CoinGecko's authentication documentation);
    /// `nil` without a key
    static func headers() -> [(field: String, value: String)]? {
        if let apiKey {
            return [(field: "x-cg-pro-api-key", value: apiKey)]
        }
        return demoApiKey.map { [(field: "x-cg-demo-api-key", value: $0)] }
    }

    // Set from any concurrency domain and read from any, so each is held behind a `Mutex`.
    private static let _apiKey = Mutex<String?>(nil)
    static var apiKey: String? {
        get { _apiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment["COIN_GECKO_KEY"] }
        set { _apiKey.withLock { $0 = newValue } }
    }

    private static let _demoApiKey = Mutex<String?>(nil)
    static var demoApiKey: String? {
        get { _demoApiKey.withLock { $0 } ?? ProcessInfo.processInfo.environment["COIN_GECKO_DEMO_KEY"] }
        set { _demoApiKey.withLock { $0 = newValue } }
    }
}
