// UInt128+Codable.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

extension NBKDoubleWidth: Codable where High: Codable, High.Magnitude: Codable, Low: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let low = try container.decode(Low.self, forKey: .low)
        let high = try container.decode(High.self, forKey: .high)

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

extension NBKDoubleWidth {
    @inlinable init(stringLiteral source: String) {
        let decoder = NBK.IntegerDescription.DecoderDecodingRadix<Magnitude>()
        guard let components = decoder.decode(source) else {
            fatalError("Unable to convert \(source) to NBKDoubleWidth")
        }

        self.init(sign: components.sign, magnitude: components.magnitude)!
    }
}
