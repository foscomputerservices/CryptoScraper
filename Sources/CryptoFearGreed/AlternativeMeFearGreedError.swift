// AlternativeMeFearGreedError.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Why ``AlternativeMeFearGreedClient`` could not hand up a day, where the response itself arrived
///
/// ```swift
/// catch AlternativeMeFearGreedError.malformedValue(let text) { … }
/// ```
public enum AlternativeMeFearGreedError: Error, Hashable, Sendable {
    /// A `value` that is not a whole number from 0 to 100 in ASCII digits only, as the publisher wrote it
    case malformedValue(String)
    /// A `timestamp` that is not whole Unix seconds in ASCII digits only, as the publisher wrote it
    case malformedTimestamp(String)
}
