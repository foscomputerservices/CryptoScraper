// Decodable.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

enum JSONError: Error {
    case error(message: String, failureReason: String)
}

extension String {
    /// Converts the `String` to and instance of `T` from JSON string using `JSONDecoder`.defaultDecoder
    func fromJSON<T>() throws -> T where T: Decodable {
        guard let jsonData = data(using: .utf8), !jsonData.isEmpty else {
            throw JSONError.error(
                message: "Unable to convert the string to .utf8 data",
                failureReason: isEmpty ? "String is empty" : "Unknown"
            )
        }

        return try jsonData.fromJSON()
    }
}

extension Data {
    /// Converts the `Data` to `T` from the JSON string encoded in `Data` using `JSONDecoder`.defaultDecoder
    func fromJSON<T>() throws -> T where T: Decodable {
        try JSONDecoder.defaultDecoder.decode(T.self, from: self)
    }
}
