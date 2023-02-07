// DecodingError.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension DecodingError {
    var localizedDescription: String {
        switch self {
        case .dataCorrupted(let context):
            return "Data Corrupted: \(context.codingPath) - \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Key Not Found: \(key) - \(context.codingPath) - \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Type Mismatch: \(type) - \(context.codingPath) - \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Value Not Found: \(type) - \(context.codingPath) - \(context.debugDescription)"
        @unknown default:
            return "Unknown **new** error"
        }
    }
}
