// CoinMarketCapError.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Surfaces CoinMarketCapErrors
///
/// - See also: https://coinmarketcap.com/api/documentation/v1/#section/Standards-and-Conventions
public struct CoinMarketCapError: Decodable, Error {
    public let status: ErrorStatus

    /// Returns **true** when the API Key's rate limit was exceeded
    public var rateLimitReached: Bool {
        status.errorCode == 429
    }

    public struct ErrorStatus: Decodable {
        public let timestamp: String
        public let errorCode: Int
        public let errorMessage: String?
        public let elapsed: Int
        public let creditCount: Int

        var localizedDescription: String {
            "\(errorCode): \(errorMessage ?? "Unknown")"
        }

        enum CodingKeys: String, CodingKey {
            case timestamp
            case errorCode = "error_code"
            case errorMessage = "error_message"
            case elapsed
            case creditCount = "credit_count"
        }
    }

    public var localizedDescription: String {
        status.localizedDescription
    }

    public init(status: ErrorStatus) {
        self.status = status
    }

    public init(message: String) {
        self.status = .init(
            timestamp: "0",
            errorCode: 0,
            errorMessage: message,
            elapsed: 0, creditCount: 0
        )
    }
}

public struct CoinMarketCapResponseError: Decodable, Error {
    let statusCode: Int
    let error: String
    let message: String

    public var localizedDescription: String {
        "\(statusCode): \(error) - \(message)"
    }
}
