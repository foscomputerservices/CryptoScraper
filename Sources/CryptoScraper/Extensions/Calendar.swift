//
//  File.swift
//  
//
//  Created by David Hunt on 4/29/24.
//

import Foundation

public extension Calendar {

    static let asia: Self = {
        var result = Calendar.current
        result.timeZone = .init(identifier: "Asia/Hong_Kong")!
        return result
    }()

    static let london: Self = {
        var result = Calendar.current
        result.timeZone = .init(identifier: "Europe/London")!
        return result
    }()

    static let us: Self = {
        var result = Calendar.current
        result.timeZone = .init(identifier: "America/New_York")!
        return result
    }()
}
