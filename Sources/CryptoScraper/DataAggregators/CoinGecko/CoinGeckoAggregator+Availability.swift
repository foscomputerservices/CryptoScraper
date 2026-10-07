// CoinGeckoAggregator+Availability.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinGeckoAggregator {
    /// Returns **true** if the site is responding
    func isAlive() async -> Bool {
        do {
            let _: String = try await Self.endPoint.appending(path: "ping").fetch(headers: Self.headers())
            return true
        } catch {
            return false
        }
    }
}
