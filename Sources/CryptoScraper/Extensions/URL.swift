// URL.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension URL {
    func fetch<ResultValue: Decodable>(_ dataFetch: FoundationDataFetch? = nil) async throws -> ResultValue {
        try await (dataFetch ?? FoundationDataFetch.default).fetch(self)
    }

    // This is a replacement for the macOS 13 only api
    public func appending(queryItems: [URLQueryItem]) -> URL {
        URL(string: absoluteString + queryItems.queryStr)!
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
