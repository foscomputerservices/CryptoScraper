// URL.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension URL {
    func fetch<ResultValue: Decodable>(_ dataFetch: FoundationDataFetch? = nil) async throws -> ResultValue {
        try await (dataFetch ?? FoundationDataFetch.default).fetch(self)
    }

    /// Fetches the given data of type ``ResultValue`` from the given ``URL``
    ///
    /// - Parameters:
    ///   - dataFetch: An optional implementation of ``FoundationDataFetch`` to use to retrieve the data
    ///   - errorType: An ``Error`` type to attempt to decode returned data as an error if unable to decode as ``ResultValue``
    func fetch<ResultValue: Decodable>(_ dataFetch: FoundationDataFetch? = nil, errorType: (some Decodable & Error).Type) async throws -> ResultValue {
        try await (dataFetch ?? FoundationDataFetch.default).fetch(self, errorType: errorType)
    }

    // These are replacements for the macOS 13 only api
    func appending(queryItems: [URLQueryItem]) -> URL {
        URL(string: absoluteString + queryItems.queryStr)!
    }

    func appending(path: some StringProtocol) -> URL {
        appendingPathComponent(String(path))
    }
}

private extension Collection<URLQueryItem> {
    var queryStr: String {
        reduce("") { result, next in
            var result = result

            result += result.isEmpty ? "?" : "&"
            result += next.name
            result += "="
            result += next.value!

            return result
        }
    }
}
