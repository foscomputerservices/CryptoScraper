// UInt128+Codable.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension UInt128: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let low = try container.decode(UInt.self, forKey: .low)
        let high = try container.decode(UInt.self, forKey: .high)

        self.init(ascending: (low: low, high: high))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(low, forKey: .low)
        try container.encode(high, forKey: .high)
    }

    private enum CodingKeys: String, CodingKey {
        case low
        case high
    }
}
