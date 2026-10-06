// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite (AR14): each maps one signature the isolated projector
// invented onto a real member of the libraries. No assertion of a projected file is edited; a test that stays red is
// classified in the builder's ledger with its reason.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import FOSFoundation
import Foundation
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
    static let exponents: [String: Int] = ["BTC": 5, "ETH": 4, "USDC": 6]
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

// MARK: Hyperliquid's constructors

extension HyperliquidMarketName: ExpressibleByStringLiteral {
    /// The projector writes a market as a literal; it is validated as Hyperliquid spells it
    public init(stringLiteral value: String) {
        do {
            try self.init(validating: value)
        } catch {
            preconditionFailure("A literal market Hyperliquid cannot spell: \(value)")
        }
    }
}

extension HyperliquidAgentKey {
    /// The key from its hex text, "0x" optional
    init(hex: String) throws {
        let digits = Array(hex.hasPrefix("0x") ? hex.dropFirst(2) : Substring(hex))
        guard digits.count % 2 == 0 else { throw HyperliquidClientError.malformedAgentKey }
        var bytes = Data()
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(digits[index..<index + 2]), radix: 16) else { throw HyperliquidClientError.malformedAgentKey }
            bytes.append(byte)
        }
        try self.init(privateKey: bytes)
    }
}

extension HyperliquidClient {
    /// `session:` through the bridge; `log:` has nothing to receive (the client writes no line); `nonce:` is the clock
    init(credential: HyperliquidCredential?, endpoint: HyperliquidEndpoint, session: any ExchangeClientSession,
         log: @escaping @Sendable (String) -> Void = { _ in }, nonce: (@Sendable () -> UInt64)? = nil) throws {
        let clock: @Sendable () -> Date
        if let nonce {
            clock = { Date(timeIntervalSince1970: Double(nonce()) / 1000) }
        } else {
            clock = { Date() }
        }
        self.init(credential: credential, endpoint: endpoint, session: BehavioralSessionBridge(seam: session), now: clock)
    }
}

/// The projector's signing seam over the client's own signing (AR33): the action read in its key order, hashed,
/// digested and signed exactly as the client does for an order
struct HyperliquidSigner {
    let key: HyperliquidAgentKey

    init(agentKey: HyperliquidAgentKey) {
        self.key = agentKey
    }

    var address: String { key.address }

    struct Signed {
        let actionBytes: Data
        let actionHash: Data
        let typedDataHash: Data
        let r: Data
        let s: Data
        let v: Int
    }

    func sign(actionJSON: Data, nonce: UInt64, vaultAddress: String?, isMainnet: Bool) throws -> Signed {
        let action = OrderedJSON.parse(String(decoding: actionJSON, as: UTF8.self))
        let hash = try HyperliquidSigning.actionHash(action, nonce: nonce, vaultAddress: vaultAddress)
        let digest = HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: isMainnet)
        let signature = key.sign(digest: digest)
        return Signed(actionBytes: Data(action.messagePack), actionHash: Data(hash), typedDataHash: Data(digest),
                      r: Data(signature.r), s: Data(signature.s), v: signature.v)
    }
}

extension HyperliquidClient {
    // The signing fixture names a market as text: each call validates it as Hyperliquid spells it.
    func placeOrder(market: String, side: ExchangeClientSide, size: Amount, limit: Price, immediateOrCancel: Bool, reduceOnly: Bool,
                    account: String) async throws -> ExchangeClientOrderResult<HyperliquidOrderId> {
        try await placeOrder(market: HyperliquidMarketName(validating: market), side: side, size: size, limit: limit,
                             immediateOrCancel: immediateOrCancel, reduceOnly: reduceOnly, account: account)
    }

    func cancelOrder(_ id: HyperliquidOrderId, market: String, account: String) async throws {
        try await cancelOrder(id, market: HyperliquidMarketName(validating: market), account: account)
    }

    func setLeverage(_ leverage: Int, market: String, isolated: Bool, account: String) async throws {
        try await setLeverage(leverage, market: HyperliquidMarketName(validating: market), isolated: isolated, account: account)
    }
}
