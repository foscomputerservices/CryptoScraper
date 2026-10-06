// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite (AR14): each maps one signature the isolated projector
// invented onto a real member of the libraries. No assertion of a projected file is edited; a test that stays red is
// classified in the builder's ledger with its reason.

import CryptoAsset
import CryptoExchange
import CryptoKraken
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: The session seam → FOSFoundation's mockable session (AR31)

/// The projector's URLSession-shaped seam; its scripted double conforms to it, and BehavioralSessionBridge hands it
/// to a client as the URLSessionProtocol FOSFoundation's fetch takes
protocol ExchangeClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// An ExchangeClientSession as FOSFoundation's URLSessionProtocol: each task answers from the seam, never the network
struct BehavioralSessionBridge: URLSessionProtocol {
    let seam: any ExchangeClientSession

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
        fatalError("BehavioralSessionBridge is made over a seam")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

// MARK: The typed errors the projector invented: declared here so its files compile; each client throws its own

/// The projector's shared error; no client throws it (C31: each client its own typed errors), so a test expecting it
/// is red and classified
enum ExchangeClientError: Error, Equatable {
    case rateLimited(retryAfter: Duration?)
    case malformedResponse
    case unreachable
    case unauthorized
    case exchange(code: String?, text: String)
}

// MARK: The exact text constructors → the package's one parse (WireDecimal)

/// The exponent each symbol has on this target's exchange, from its recordings
enum BehavioralAssets {
    static let exponents: [String: Int] = ["BTC": 10, "XBT": 10, "USD": 4, "USDC": 6]
    static let priceBase = "BTC"

    static func asset(_ symbol: String) throws -> Asset {
        try Asset(symbol: symbol, unitExponent: exponents[symbol] ?? 8)
    }
}

extension Asset {
    init(symbol: String) throws {
        self = try BehavioralAssets.asset(symbol)
    }
}

extension Amount {
    init(parsing text: String, of asset: Asset) throws {
        self = try WireDecimal(parsing: text).amount(of: asset)
    }
}

extension Price {
    /// The invented signature names no base asset: the base is this target's market's (BehavioralAssets/priceBase)
    init(parsing text: String, in quote: Asset) throws {
        self = try WireDecimal(parsing: text).price(of: quote, per: BehavioralAssets.asset(BehavioralAssets.priceBase))
    }
}

extension Fraction {
    init(parsing text: String) throws {
        self = try WireDecimal(parsing: text).fraction()
    }
}

// MARK: Kraken's constructors

extension KrakenMarketName: ExpressibleByStringLiteral {
    /// The projector writes a market as a literal; it is validated as Kraken spells it
    public init(stringLiteral value: String) {
        do {
            try self.init(validating: value)
        } catch {
            // Kraken spot cannot spell it (the projector's futures symbol "PF_XBTUSD"): the test is red, never a crash
            Issue.record("A literal market Kraken spot cannot spell: \(value)")
            self = .stub()
        }
    }
}

extension KrakenCredential {
    /// The projector's `.apiKey(_:secret:)`: Kraken's API key and its base64 secret
    static func apiKey(_ key: String, secret: String) throws -> KrakenCredential {
        try KrakenCredential(apiKey: key, base64Secret: secret)
    }
}

/// The projector's endpoint; Kraken spot has one, and no test market (`hasTestMarket` is false), so either case is it
enum KrakenEndpoint {
    case testMarket
    case production
}

extension KrakenClient {
    /// `session:` through the bridge; `log:` has nothing to receive (the client writes no line)
    init(credential: KrakenCredential, endpoint: KrakenEndpoint, session: any ExchangeClientSession,
         log: @escaping @Sendable (String) -> Void = { _ in }) throws {
        self.init(credential: credential, session: BehavioralSessionBridge(seam: session))
    }
}
// Wiring, 2026-10-06: C31's maintenanceWindows() now returns ExchangeClientMaintenanceWindow (subject, interval, text);
// the projected assertion compares the windows with bare intervals, so it compares the intervals.
func == (windows: [ExchangeClientMaintenanceWindow], intervals: [DateInterval]) -> Bool {
    windows.map(\.interval) == intervals
}
