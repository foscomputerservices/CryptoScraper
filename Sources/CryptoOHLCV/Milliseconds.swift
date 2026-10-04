// Milliseconds.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

// Feeds count time in whole milliseconds since 1970 UTC. Every comparison of two bar times in this library is made
// on those integers, never on the Date's floating seconds, so a bar is the same bar however it was decoded.

extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    // The nearest whole millisecond: a Date decoded from a feed's millisecond carries exactly that millisecond back.
    var milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}

extension BarInterval {
    // The interval's length in milliseconds: a minute, an hour, a day and a week are fixed lengths of UTC time, so
    // this is arithmetic and no calendar.
    var milliseconds: Int64 {
        let unit: Int64 = switch self.unit {
        case .minute: 60_000
        case .hour: 3_600_000
        case .day: 86_400_000
        case .week: 604_800_000
        }
        return Int64(count) * unit
    }

    // The interval as a short file-name token: "15m", "4h", "1d", "1w".
    var token: String {
        let letter = switch unit {
        case .minute: "m"
        case .hour: "h"
        case .day: "d"
        case .week: "w"
        }
        return "\(count)\(letter)"
    }
}
