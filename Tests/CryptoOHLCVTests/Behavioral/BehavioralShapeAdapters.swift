// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite of the OHLCV clients (AR14): each maps one signature
// the isolated projector invented onto a real member. No assertion of a projected file is edited; a test that stays
// red is classified in the builder's ledger with its reason. (Adapters.swift is step 2's, for step 2's files.)

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The projector's URLSession-shaped seam for a feed client
protocol OHLCVClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// An OHLCVClientSession as FOSFoundation's URLSessionProtocol: each task answers from the seam, never the network
struct FeedSessionBridge: URLSessionProtocol {
    let seam: any OHLCVClientSession

    func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        let seam = seam
        Task {
            do {
                let (data, response) = try await seam.data(for: request)
                completionHandler(data, response, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("FeedSessionBridge is made over a seam")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

/// The projector's shared feed error; each client throws its own typed errors, so a test expecting this is red and
/// classified
enum OHLCVClientError: Error, Equatable {
    case rateLimited(retryAfter: Duration?)
    case malformedResponse
}

// The exact text constructors → the package's one parse. The invented signatures name no exponent and no base, so
// the exponent is the one the symbol has on most of the four feeds and a price's base is BTC at it.
enum FeedAssets {
    static let exponents: [String: Int] = ["BTC": 8, "USDT": 8, "USDC": 6, "USD": 2]

    static func asset(_ symbol: String) throws -> Asset {
        try Asset(symbol: symbol, unitExponent: exponents[symbol] ?? 8)
    }
}

extension Asset {
    init(symbol: String) throws {
        self = try FeedAssets.asset(symbol)
    }
}

extension Amount {
    init(parsing text: String, of asset: Asset) throws {
        self = try WireDecimal(parsing: text).amount(of: asset)
    }
}

extension Price {
    init(parsing text: String, in quote: Asset) throws {
        self = try WireDecimal(parsing: text).price(of: quote, per: FeedAssets.asset("BTC"))
    }
}

// The four conformers' `(session:now:)`.

extension BinanceOHLCVClient {
    /// Binance's market's assets passed in (BTCUSDT, both at Binance's precision 8), so no exchangeInfo is asked
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        let btcusdt = BinanceMarket(name: .stub(text: "BTCUSDT"), base: try! FeedAssets.asset("BTC"), quote: try! FeedAssets.asset("USDT"))
        self.init(session: FeedSessionBridge(seam: session), markets: [btcusdt], now: now)
    }
}

extension HyperliquidOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

extension KrakenOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

extension CoinbaseOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

// The projector writes each feed's market as a literal.

extension HyperliquidMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension KrakenMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension CoinbaseMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension BinanceMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}
