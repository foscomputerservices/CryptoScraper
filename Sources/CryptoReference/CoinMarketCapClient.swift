// CoinMarketCapClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// CoinMarketCap's reference client, on `/v1/cryptocurrency/listings/latest`
///
/// Each request goes through FOSFoundation's fetch with ``CoinMarketCapError`` as its error type, the API key in
/// the `X-CMC_PRO_API_KEY` header, asking for the ranking with its aux fields `cmc_rank`, `date_added`, `tags`,
/// `platform` and `is_market_cap_included_in_calc`. No symbols asked for makes no request. The listing is read a page
/// at a time, in rank order, until a page ends with every symbol asked for found at least once, or the listing ends.
///
/// ```swift
/// let client = CoinMarketCapClient(apiKey: key)
/// let assets = try await client.reference(symbols: [try .init(validating: "BTC"), try .init(validating: "ETH")])
/// assets.map(\.rank)          // [1, 2]
/// ```
///
/// Every listed asset whose symbol is one asked for, on the pages read, is handed up in rank order: CoinMarketCap
/// lists some symbols more than once (two MEME), each with its own ``ReferenceClientAsset/aggregatorId``, and which of
/// them is meant is the caller's to say. A duplicate on a page after the one that completed the symbols is not read.
/// Each carries the `platform` CoinMarketCap states, addresses as received, and its instance where the library's table
/// of CoinMarketCap's chain names holds the chain and the joined id validates. A listed symbol that is not a
/// well-formed ``AssetSymbol`` cannot be one asked for and is passed over.
public struct CoinMarketCapClient: ReferenceClient {
    /// CoinMarketCap's largest page of the listing
    public static let largestPage = 5000

    private let apiKey: String
    private let baseURL: URL
    private let session: any URLSessionProtocol
    private let pageSize: Int

    /// - Parameters:
    ///   - apiKey: The CoinMarketCap API key
    ///   - baseURL: CoinMarketCap's REST root
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - pageSize: The listing's rows per request, 1 through 5,000; a value outside that range is a precondition failure
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://pro-api.coinmarketcap.com")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        pageSize: Int = CoinMarketCapClient.largestPage
    ) {
        precondition((1...Self.largestPage).contains(pageSize), "CoinMarketCapClient pageSize outside 1 through 5,000")
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
        self.pageSize = pageSize
    }

    public func reference(symbols: [AssetSymbol]) async throws -> [ReferenceClientAsset] {
        let wanted = Set(symbols)
        guard !wanted.isEmpty else { return [] }

        var found: [ReferenceClientAsset] = []
        var seen: Set<AssetSymbol> = []
        var start = 1
        while true {
            let page = try await listings(start: start)
            for row in page.data {
                guard let symbol = try? AssetSymbol(validating: row.symbol), wanted.contains(symbol) else { continue }
                found.append(ReferenceClientAsset(
                    symbol: symbol,
                    name: row.name,
                    rank: row.rank,
                    tags: row.tags,
                    isCountedInMarketCap: row.isCountedInMarketCap,
                    aggregatorId: String(row.id),
                    platform: row.platform,
                    instance: Self.instance(on: row.platform)
                ))
                seen.insert(symbol)
            }
            // The whole listing is read when a page comes back short; all asked for are found at the page's end.
            if page.data.count < pageSize || seen == wanted {
                break
            }
            start += pageSize
        }
        return found
    }

    // The one place this client forms an instance id (step 5 of the identity PR, a reading recorded in its ledger
    // for the owner's pen): the chain's CAIP-2 id from the library's table of CoinMarketCap's chain names, joined at
    // a colon to the address as CoinMarketCap gives it, then validated. No platform (a native coin), a chain the
    // table does not name, or an id that does not validate gives no instance; the platform stays as the fact.
    private static func instance(on platform: ReferenceClientAsset.Platform?) -> AssetInstance? {
        guard let platform,
              let chainId = try? AssetRegistry.chainId(named: platform.name, by: .coinMarketCap) else {
            return nil
        }
        return try? AssetInstance(validating: chainId + ":" + platform.tokenAddress)
    }

    private func listings(start: Int) async throws -> CoinMarketCapListings {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/v1/cryptocurrency/listings/latest"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "aux", value: "cmc_rank,date_added,tags,platform,is_market_cap_included_in_calc")
        ]
        guard let url = components.url else {
            throw DataFetchError.badURL("listings/latest start \(start)")
        }
        return try await DataFetch(urlSession: SessionBox(base: session)).fetch(
            url,
            headers: [(field: "X-CMC_PRO_API_KEY", value: apiKey)],
            errorType: CoinMarketCapError.self
        )
    }
}

/// The error CoinMarketCap states in its envelope's `status`: `error_code` and `error_message`
///
/// ```swift
/// catch let error as CoinMarketCapError where error.code == 1002 { … }     // the API key is missing
/// ```
///
/// CoinMarketCap's codes: 1001 an invalid key, 1002 a missing key, 1006 a plan without the endpoint, 1008 to 1011
/// a rate or credit limit.
public struct CoinMarketCapError: Error, Decodable, Hashable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    private enum EnvelopeKeys: String, CodingKey {
        case status
    }

    private enum StatusKeys: String, CodingKey {
        case code = "error_code"
        case message = "error_message"
    }

    // A status of 0 is CoinMarketCap's success, never an error, so an answer that failed to decode for another
    // reason is not mistaken for one.
    public init(from decoder: any Decoder) throws {
        let status = try decoder.container(keyedBy: EnvelopeKeys.self)
            .nestedContainer(keyedBy: StatusKeys.self, forKey: .status)
        let code = try status.decode(Int.self, forKey: .code)
        guard code != 0 else {
            throw DecodingError.dataCorruptedError(forKey: .code, in: status, debugDescription: "error_code 0 is success")
        }
        self.code = code
        self.message = try status.decodeIfPresent(String.self, forKey: .message) ?? ""
    }
}

// MARK: Response models

// The listing's envelope, and the fields of a row this client reads.
struct CoinMarketCapListings: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        let id: Int
        let symbol: String
        let name: String
        let rank: Int
        let tags: [String]
        let isCountedInMarketCap: Bool
        let platform: ReferenceClientAsset.Platform?

        private enum CodingKeys: String, CodingKey {
            case id
            case symbol
            case name
            case rank = "cmc_rank"
            case tags
            case isCountedInMarketCap = "is_market_cap_included_in_calc"
            case platform
        }

        // The platform's fields this client reads, as CoinMarketCap names them.
        private enum PlatformKeys: String, CodingKey {
            case name
            case tokenAddress = "token_address"
        }

        init(from decoder: any Decoder) throws {
            let row = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try row.decode(Int.self, forKey: .id)
            // A native coin's platform is null; a row without the field is read the same.
            if try !row.contains(.platform) || row.decodeNil(forKey: .platform) {
                self.platform = nil
            } else {
                let platform = try row.nestedContainer(keyedBy: PlatformKeys.self, forKey: .platform)
                self.platform = try ReferenceClientAsset.Platform(
                    name: platform.decode(String.self, forKey: .name),
                    tokenAddress: platform.decode(String.self, forKey: .tokenAddress)
                )
            }
            self.symbol = try row.decode(String.self, forKey: .symbol)
            self.name = try row.decode(String.self, forKey: .name)
            self.rank = try row.decode(Int.self, forKey: .rank)
            self.tags = try row.decodeIfPresent([String].self, forKey: .tags) ?? []
            // CoinMarketCap sends 1 or 0; a Bool is read as well.
            if let flag = try? row.decode(Int.self, forKey: .isCountedInMarketCap) {
                self.isCountedInMarketCap = flag != 0
            } else {
                self.isCountedInMarketCap = try row.decode(Bool.self, forKey: .isCountedInMarketCap)
            }
        }
    }

    let data: [Row]
}

// DataFetch is generic over its session's concrete type; this carries the caller's session of any type.
struct SessionBox: URLSessionProtocol {
    let base: any URLSessionProtocol

    func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        base.dataTask(with: url, completionHandler: completionHandler)
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        base.dataTask(with: request, completionHandler: completionHandler)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        Self(base: URLSession.session(config: config))
    }
}
