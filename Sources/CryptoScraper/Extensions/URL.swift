// URL.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension URL {
    func fetch<ResultValue: Decodable>(_ dataFetch: FoundationDataFetch? = nil) async throws -> ResultValue {
        try await (dataFetch ?? FoundationDataFetch.default).fetch(self)
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
