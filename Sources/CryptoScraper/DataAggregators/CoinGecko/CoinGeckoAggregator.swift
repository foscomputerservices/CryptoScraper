// CoinGeckoAggregator.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct CoinGeckoAggregator: CryptoDataAggregator {
    // MARK: CryptoChain

    public let userReadableName: String = "Coin Gecko"

    static let endPoint: URL = {
        if let apiKey {
            return .init(string: "https://pro-api.coingecko.com/api/v3")!
        }

        return .init(string: "http://api.coingecko.com/api/v3")!
    }()

    static var apiKey: String? {
        ProcessInfo.processInfo.environment["COIN_GECKO_KEY"]
    }

    public init() {}
}
