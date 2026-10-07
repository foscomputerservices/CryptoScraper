// PolkadotContract+Addresses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// The address shape the Polkadot-family relay chains share, read by each one's own contract (`polkadot`, design
// § 2.5).
extension PolkadotContract {
    /// The SS58 prefix `text` decodes to as an account of 32 bytes, the network it was written for: one byte for a
    /// prefix below 64, two for one from 64 to 16,383; `nil` when `text` is not base58 of a prefix, 32 bytes and a
    /// two-byte checksum
    ///
    /// The checksum is not verified.
    static func ss58Prefix(_ text: String) -> Int? {
        guard let bytes = BitcoinContract.base58Bytes(text), let first = bytes.first else {
            return nil
        }
        switch first {
        case 0..<64 where bytes.count == 1 + 32 + 2:
            return Int(first)
        case 64..<128 where bytes.count == 2 + 32 + 2:
            let second = bytes[1]
            return Int((first & 0x3F) << 2 | second >> 6) | Int(second & 0x3F) << 8
        default:
            return nil
        }
    }
}
