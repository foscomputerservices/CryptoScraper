// BarInterval.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A bar's length as a feed takes it: a count and a unit, never a duration
///
/// ```swift
/// let quarterHour = BarInterval(count: 15, unit: .minute)
/// ```
public struct BarInterval: Codable, Hashable, Sendable, Stubbable {
    public enum Unit: Codable, Hashable, Sendable { case minute, hour, day, week }
    public let count: Int
    public let unit: Unit
    public init(count: Int, unit: Unit) {
        self.count = count
        self.unit = unit
    }
}

// MARK: Stubs

extension BarInterval {
    public static func stub() -> Self { .stub(count: 42) }

    public static func stub(count: Int = 42, unit: Unit = .minute) -> Self {
        .init(count: count, unit: unit)
    }
}
