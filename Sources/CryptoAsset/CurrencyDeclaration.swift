// CurrencyDeclaration.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// Which holdings stand for a currency: each is accepted where the currency is named, one for one, with no conversion
/// and no rate
///
/// Used where a stream names its unit of account as a currency, `iso4217:USD`, and a feed or an exchange counts in a
/// holding of its own: Binance's tether, Hyperliquid's USDC, Kraken's dollar. Each exchange chain declares its own beside
/// its holdings, in its client's registry; a holding stands for one currency at most. Standing for a currency says
/// nothing of the holding's asset: Hyperliquid's USDC stays an instance of USD Coin, at its own decimals.
///
/// ```swift
/// try registry.add([CurrencyDeclaration(currency: ISO4217.usd.instance, holdings: [hyperliquidUSDC])])
/// try registry.holding(standingFor: ISO4217.usd.instance, on: "exchange:hyperliquid")     // hyperliquidUSDC
/// try registry.currency(of: hyperliquidUSDC)                                              // iso4217:USD
/// ```
public struct CurrencyDeclaration: Codable, Hashable, Sendable, Stubbable {
    /// The currency, an `iso4217` instance
    public let currency: AssetInstance
    /// The holdings that stand for it, on chains or exchanges
    public let holdings: [AssetInstance]

    public init(currency: AssetInstance, holdings: [AssetInstance]) {
        self.currency = currency
        self.holdings = holdings
    }
}

// MARK: Stubs

extension CurrencyDeclaration {
    public static func stub() -> Self { .stub(currency: ISO4217.usd.instance) }

    /// The dollar, stood for by the stub instance
    public static func stub(currency: AssetInstance = ISO4217.usd.instance, holdings: [AssetInstance] = [.stub()]) -> Self {
        .init(currency: currency, holdings: holdings)
    }
}
