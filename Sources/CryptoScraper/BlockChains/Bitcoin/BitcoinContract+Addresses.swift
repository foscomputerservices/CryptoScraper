// BitcoinContract+Addresses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// The address shapes the Bitcoin family shares, read by each family chain's own contract (`bip122`, design § 2.5).
// Bitcoin's own contract keeps every address as given, as it did; nothing here changes it.
extension BitcoinContract {
    /// The bytes `text` decodes to as base58 (Bitcoin's alphabet), each leading `1` one leading zero byte; `nil` when
    /// a character is outside the alphabet
    ///
    /// The base58check checksum, the last four bytes, is not verified.
    static func base58Bytes(_ text: String) -> [UInt8]? {
        guard !text.isEmpty else {
            return nil
        }
        var bytes: [UInt8] = []
        for character in text {
            guard var carry = base58Alphabet.firstIndex(of: character) else {
                return nil
            }
            for index in bytes.indices.reversed() {
                carry += Int(bytes[index]) * 58
                bytes[index] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }
        let leadingZeros = text.prefix { $0 == "1" }.count
        return Array(repeating: 0, count: leadingZeros) + bytes.drop { $0 == 0 }
    }

    /// The version of `text` as a base58check address of a 20-byte hash, its version `versionByteCount` bytes long
    /// (one on most chains, two on Zcash) read as one number; `nil` when `text` is not base58 of exactly that length
    ///
    /// The checksum is not verified.
    static func base58AddressVersion(_ text: String, versionByteCount: Int = 1) -> Int? {
        guard let bytes = base58Bytes(text), bytes.count == versionByteCount + 20 + 4 else {
            return nil
        }
        return bytes.prefix(versionByteCount).reduce(0) { $0 << 8 | Int($1) }
    }

    /// Whether `text` is a segregated-witness address of the chain whose bech32 human-readable part is
    /// `humanReadablePart`: lower case, `<hrp>1`, then a version-0 program of 20 or 32 bytes (`q` and 38 or 58 more
    /// characters) or a version-1 program of 32 bytes (`p` and 58 more), in bech32's alphabet
    ///
    /// The bech32 checksum is not verified; an upper-case address, which BIP 173 allows, is refused, since lower case
    /// is the form the chains write.
    static func isWitnessAddress(_ text: String, humanReadablePart: String) -> Bool {
        let prefix = humanReadablePart + "1"
        guard text.hasPrefix(prefix) else {
            return false
        }
        let data = text.dropFirst(prefix.count)
        guard data.allSatisfy({ bech32Alphabet.contains($0) }), let version = data.first else {
            return false
        }
        switch version {
        case "q": return data.count == 39 || data.count == 59
        case "p": return data.count == 59
        default: return false
        }
    }

    /// Bech32's alphabet, which CashAddr shares
    static let bech32Alphabet = Set("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
}
