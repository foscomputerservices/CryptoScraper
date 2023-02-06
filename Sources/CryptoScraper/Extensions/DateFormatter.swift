// DateFormatter.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension DateFormatter {
    /// Formats dates without times using GMT-0
    @nonobjc static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        #if !os(WASI)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        #endif
        return formatter
    }()

    /// Formats dates with times using GMT-0
    @nonobjc static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        #if !os(WASI)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        #endif
        return formatter
    }()

    /// A full date-time representation for encoding in JSON using GMT-0
    @nonobjc static let JSONDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        #if !os(WASI)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSS'Z'"
        #endif
        return formatter
    }()

    @nonobjc static let ISO8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        #if !os(WASI)
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        #endif
        return formatter
    }()
}
