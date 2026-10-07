// ZilliqaContract+Addresses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// Zilliqa writes an address two ways, bech32 under `zil` (its canonical form) and 20 bytes in hex; BIP 173's bech32,
// read and written here with its checksum.
extension ZilliqaContract {
    /// The human-readable part of every Zilliqa bech32 address
    static let humanReadablePart = "zil"

    /// The bytes `text` holds as bech32 under `zil`, in lower case, its checksum verified; `nil` for any other text
    static func bytes(bech32 text: String) -> [UInt8]? {
        let prefix = humanReadablePart + "1"
        guard text.hasPrefix(prefix), text.count > prefix.count + 6 else {
            return nil
        }
        var values: [UInt8] = []
        for character in text.dropFirst(prefix.count) {
            guard let index = alphabet.firstIndex(of: character) else {
                return nil
            }
            values.append(UInt8(index))
        }
        guard polymod(expanded(humanReadablePart) + values) == 1 else {
            return nil
        }
        return regrouped(Array(values.dropLast(6)), from: 5, to: 8, padding: false)
    }

    /// `bytes` as bech32 under `zil`, in lower case, its checksum appended
    static func bech32(_ bytes: [UInt8]) -> String {
        let values = regrouped(bytes, from: 8, to: 5, padding: true) ?? []
        let check = polymod(expanded(humanReadablePart) + values + [0, 0, 0, 0, 0, 0]) ^ 1
        let checksum = (0..<6).map { UInt8((check >> (5 * (5 - $0))) & 31) }
        return humanReadablePart + "1" + String((values + checksum).map { alphabet[Int($0)] })
    }

    /// The bytes `text` writes as hex digits, two each, either case; `nil` for any other text
    static func bytes(hex text: some StringProtocol) -> [UInt8]? {
        let digits = Array(text)
        guard digits.count.isMultiple(of: 2) else {
            return nil
        }
        return stride(from: 0, to: digits.count, by: 2).reduce(into: [UInt8]?([])) { bytes, index in
            guard let byte = UInt8(String(digits[index...index + 1]), radix: 16) else {
                bytes = nil
                return
            }
            bytes?.append(byte)
        }
    }

    private static let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private static func expanded(_ part: String) -> [UInt8] {
        let scalars = part.unicodeScalars.map { UInt8($0.value) }
        return scalars.map { $0 >> 5 } + [0] + scalars.map { $0 & 31 }
    }

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        let generators: [UInt32] = [0x3B6A_57B2, 0x2650_8E6D, 0x1EA1_19FA, 0x3D42_33DD, 0x2A14_62B3]
        return values.reduce(UInt32(1)) { check, value in
            let top = check >> 25
            var next = (check & 0x1FF_FFFF) << 5 ^ UInt32(value)
            for index in 0..<5 where (top >> index) & 1 == 1 {
                next ^= generators[index]
            }
            return next
        }
    }

    private static func regrouped(_ values: [UInt8], from: Int, to: Int, padding: Bool) -> [UInt8]? {
        var accumulator = 0
        var bits = 0
        var result: [UInt8] = []
        let mask = (1 << to) - 1
        let kept = (1 << (from + to - 1)) - 1
        for value in values {
            accumulator = ((accumulator << from) | Int(value)) & kept
            bits += from
            while bits >= to {
                bits -= to
                result.append(UInt8((accumulator >> bits) & mask))
            }
        }
        if padding, bits > 0 {
            result.append(UInt8((accumulator << (to - bits)) & mask))
        } else if !padding, bits >= from || (accumulator << (to - bits)) & mask != 0 {
            return nil
        }
        return result
    }
}
