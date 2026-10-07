// EthereumScanner.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

public enum ERCTokenType: CaseIterable, Sendable {
    case erc20
    case erc721
    case erc1155
}

/// A protocol and standardized implementation of an Ethereum-style scanner
///
/// Most Ethereum-based scanners work in much the same way as they all are
/// forks of the same codebase.  Conforming to this protocol provides an
/// implementation of these standardized services.
///
/// Every conformer is one chain's configuration of Etherscan's API V2: one endpoint, ``Etherscan/endPoint``, and one
/// key, ``Etherscan/apiKey``, shared by all of them; each states only its chain, ``chainId``, which V2 is asked for
/// as its `chainid`.
public protocol EthereumScanner: CryptoScanner {
    /// Returns a set of ``ERCTokenType``s that the scanner supports
    static var supportedERCTokenTypes: Set<ERCTokenType> { get }

    /// The base URL of the scanner: Etherscan's V2 endpoint for every conformer, unless one states its own
    static var endPoint: URL { get }

    /// The name of the environment variable that stores the API key: Etherscan's, ``Etherscan/apiKeyName``, for every
    /// conformer, unless one states its own
    static var apiKeyName: String { get }

    /// The API key: Etherscan's one key, ``Etherscan/apiKey``, for every conformer, unless one states its own
    static var apiKey: String? { get set }

    /// The CAIP-2 id of the chain the scanner reads, `EIP155.<Chain>.chainId`; V2 is asked for its reference, the
    /// chain id after `eip155:`, as `chainid`
    static var chainId: String { get }

    /// A unique, but user-readable name for the scanner (e.g. Etherscan, BscScan, etc.)
    var userReadableName: String { get }
}

public extension EthereumScanner {
    /// Etherscan's V2 endpoint, the one every chain's configuration asks
    static var endPoint: URL { Etherscan.endPoint }

    /// Etherscan's one key's environment variable
    static var apiKeyName: String { Etherscan.apiKeyName }

    /// Etherscan's one key, set once for every chain's configuration
    static var apiKey: String? {
        get { Etherscan.apiKey }
        set { Etherscan.apiKey = newValue }
    }
}

extension EthereumScanner {
    /// The URL of one V2 request: the chain's `chainid` first, then `query`, then the key
    ///
    /// - Throws: ``EthereumScannerResponseError/missingApiKey(_:)`` until the key is set
    static func requestURL(_ query: [URLQueryItem]) throws -> URL {
        let chainid = URLQueryItem(name: "chainid", value: String(chainId.dropFirst(EIP155.namespace.count + 1)))
        let apikey = try URLQueryItem(name: "apikey", value: requireApiKey())

        return endPoint.appending(queryItems: [chainid] + query + [apikey])
    }

    static func requireApiKey() throws -> String {
        guard let apiKey else { throw EthereumScannerResponseError.missingApiKey(apiKeyName) }

        return apiKey
    }

    static var serviceConfigured: Bool { apiKey != nil }
}

public enum EthereumScannerResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The amount received could not be converted to a ``Amount``
    case invalidAmount

    /// The  *value* for *field* could not be converted to type *type*
    case invalidData(type: String, field: String, value: String)

    /// The API key was neither set (``Etherscan/apiKey``) nor found in the environment variable *keyName*
    case missingApiKey(_ keyName: String)

    /// Too many requests were made
    case rateLimitReached

    public var rateLimitReached: Bool {
        if case EthereumScannerResponseError.rateLimitReached = self {
            return true
        }

        return false
    }

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let message):
            return message
        case .invalidAmount:
            return "Invalid amount"
        case .invalidData(let type, let field, let value):
            return "Invalid field data '\(value)' for \(type):\(field)"
        case .missingApiKey(let keyName):
            return "An API Key was not provided in the environment \(keyName)"
        case .rateLimitReached:
            return "Rate limit reached"
        }
    }
}
