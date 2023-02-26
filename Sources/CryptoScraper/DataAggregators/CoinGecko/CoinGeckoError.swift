// CoinGeckoError.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct CoinGeckoError: Decodable, Error {
    public let status: ErrorStatus

    public var rateLimitReached: Bool {
        status.errorCode == 429
    }

    public struct ErrorStatus: Decodable {
        public let errorCode: Int
        public let errorMessage: String

        var localizedDescription: String {
            "\(errorCode): \(errorMessage)"
        }

        enum CodingKeys: String, CodingKey {
            case errorCode = "error_code"
            case errorMessage = "error_message"
        }
    }

    public var localizedDescription: String {
        status.localizedDescription
    }
}
