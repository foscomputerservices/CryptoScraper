// HyperliquidSigning.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoSwift
import Foundation

// AR33: the payload construction, the action encoding and the typed-data hash signed over, proven byte for byte
// against the POC's SDK (`@nktkas/hyperliquid` 0.33.3) by the vectors of poc/harness/hyperliquid-signing-vectors.ts.
//
// An action is an ordered value: Hyperliquid hashes its MessagePack encoding, in which a map's keys keep their order,
// so the order the SDK's schemas give is the order written here. The encoding is the SDK's encoder's (Deno's
// @std/msgpack): the smallest integer form, fixstr/str8/16/32, fixmap/map16/32, fixarray/array16/32; an integer at or
// past 2^32 as uint64 (the SDK widens such a number to a BigInt before encoding).
//
// The L1 action (an agent's order, cancel, leverage change, sub-account transfer) is signed as EIP-712's `Agent`
// under the domain "Exchange", version 1, chain 1337: its source "a" on production and "b" on the test market, its
// connection id the Keccak-256 of the action's bytes, the nonce as 8 bytes big-endian, and 0x00, or 0x01 and the
// sub-account's 20 bytes. A user-signed action (a class transfer, an agent approval) is signed as its own EIP-712 type
// under the domain "HyperliquidSignTransaction", version 1, at the chain its `signatureChainId` names.

/// One value of an action, in the order the exchange hashes it
package indirect enum HyperliquidWireValue: Hashable, Sendable {
    case map([(String, HyperliquidWireValue)])
    case array([HyperliquidWireValue])
    case string(String)
    case integer(Int64)
    case bool(Bool)
    case null

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.messagePack == rhs.messagePack
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(messagePack)
    }

    /// The MessagePack encoding the exchange hashes
    package var messagePack: [UInt8] {
        var bytes: [UInt8] = []
        append(to: &bytes)
        return bytes
    }

    /// The JSON text of the value, its maps' keys in their order
    package var json: String {
        switch self {
        case .map(let entries):
            "{" + entries.map { "\(Self.quoted($0.0)):\($0.1.json)" }.joined(separator: ",") + "}"
        case .array(let items):
            "[" + items.map(\.json).joined(separator: ",") + "]"
        case .string(let text):
            Self.quoted(text)
        case .integer(let number):
            String(number)
        case .bool(let flag):
            flag ? "true" : "false"
        case .null:
            "null"
        }
    }

    private func append(to bytes: inout [UInt8]) {
        switch self {
        case .null:
            bytes.append(0xC0)
        case .bool(let flag):
            bytes.append(flag ? 0xC3 : 0xC2)
        case .integer(let number):
            Self.append(number, to: &bytes)
        case .string(let text):
            let utf8 = Array(text.utf8)
            switch utf8.count {
            case ..<32: bytes.append(0xA0 | UInt8(utf8.count))
            case ..<256: bytes += [0xD9, UInt8(utf8.count)]
            case ..<65_536: bytes.append(0xDA); Self.appendBigEndian(UInt64(utf8.count), width: 2, to: &bytes)
            default: bytes.append(0xDB); Self.appendBigEndian(UInt64(utf8.count), width: 4, to: &bytes)
            }
            bytes += utf8
        case .array(let items):
            switch items.count {
            case ..<16: bytes.append(0x90 | UInt8(items.count))
            case ..<65_536: bytes.append(0xDC); Self.appendBigEndian(UInt64(items.count), width: 2, to: &bytes)
            default: bytes.append(0xDD); Self.appendBigEndian(UInt64(items.count), width: 4, to: &bytes)
            }
            for item in items {
                item.append(to: &bytes)
            }
        case .map(let entries):
            switch entries.count {
            case ..<16: bytes.append(0x80 | UInt8(entries.count))
            case ..<65_536: bytes.append(0xDE); Self.appendBigEndian(UInt64(entries.count), width: 2, to: &bytes)
            default: bytes.append(0xDF); Self.appendBigEndian(UInt64(entries.count), width: 4, to: &bytes)
            }
            for (key, value) in entries {
                HyperliquidWireValue.string(key).append(to: &bytes)
                value.append(to: &bytes)
            }
        }
    }

    // The SDK encoder's integer forms, smallest first.
    private static func append(_ number: Int64, to bytes: inout [UInt8]) {
        if number < 0 {
            if number >= -32 {
                bytes.append(UInt8(bitPattern: Int8(number)))
            } else if number >= -128 {
                bytes += [0xD0, UInt8(bitPattern: Int8(number))]
            } else if number >= -32_768 {
                bytes.append(0xD1); appendBigEndian(UInt64(bitPattern: number), width: 2, to: &bytes)
            } else if number >= -2_147_483_648 {
                bytes.append(0xD2); appendBigEndian(UInt64(bitPattern: number), width: 4, to: &bytes)
            } else {
                bytes.append(0xD3); appendBigEndian(UInt64(bitPattern: number), width: 8, to: &bytes)
            }
            return
        }
        switch number {
        case ...0x7F: bytes.append(UInt8(number))
        case ..<256: bytes += [0xCC, UInt8(number)]
        case ..<65_536: bytes.append(0xCD); appendBigEndian(UInt64(number), width: 2, to: &bytes)
        case ..<4_294_967_296: bytes.append(0xCE); appendBigEndian(UInt64(number), width: 4, to: &bytes)
        default: bytes.append(0xCF); appendBigEndian(UInt64(number), width: 8, to: &bytes)
        }
    }

    private static func appendBigEndian(_ value: UInt64, width: Int, to bytes: inout [UInt8]) {
        for shift in stride(from: (width - 1) * 8, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    private static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where scalar.value < 0x20: out += String(format: "\\u%04x", scalar.value)
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}

/// The hashes Hyperliquid's signatures are made over
package enum HyperliquidSigning {
    /// Keccak-256 of the action's bytes, the nonce as 8 bytes big-endian, and the sub-account marker
    package static func actionHash(_ action: HyperliquidWireValue, nonce: UInt64, vaultAddress: String?) throws -> [UInt8] {
        var bytes = action.messagePack
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: nonce >> UInt64(shift)))
        }
        if let vaultAddress {
            bytes.append(1)
            bytes += try addressBytes(vaultAddress)
        } else {
            bytes.append(0)
        }
        return keccak(bytes)
    }

    /// The EIP-712 digest of the phantom agent: `Agent(string source,bytes32 connectionId)` under "Exchange"
    package static func l1Digest(actionHash: [UInt8], isMainnet: Bool) -> [UInt8] {
        let domain = domainSeparator(name: "Exchange", chainId: 1337)
        let structHash = keccak(
            keccak(Array("Agent(string source,bytes32 connectionId)".utf8))
                + keccak(Array((isMainnet ? "a" : "b").utf8))
                + actionHash
        )
        return keccak([0x19, 0x01] + domain + structHash)
    }

    /// One field of a user-signed action's EIP-712 type
    package enum TypedField: Sendable {
        case string(String, String)
        case address(String, String)
        case bool(String, Bool)
        case uint64(String, UInt64)

        var declaration: String {
            switch self {
            case .string(let name, _): "string \(name)"
            case .address(let name, _): "address \(name)"
            case .bool(let name, _): "bool \(name)"
            case .uint64(let name, _): "uint64 \(name)"
            }
        }

        func encoded() throws -> [UInt8] {
            switch self {
            case .string(_, let text): return keccak(Array(text.utf8))
            case .address(_, let address): return [UInt8](repeating: 0, count: 12) + (try addressBytes(address))
            case .bool(_, let flag): return [UInt8](repeating: 0, count: 31) + [flag ? 1 : 0]
            case .uint64(_, let number): return word(number)
            }
        }
    }

    /// The EIP-712 digest of a user-signed action of `primaryType` ("HyperliquidTransaction:UsdClassTransfer") at
    /// the chain its signatureChainId names
    package static func userSignedDigest(primaryType: String, fields: [TypedField], signatureChainId: UInt64) throws -> [UInt8] {
        let domain = domainSeparator(name: "HyperliquidSignTransaction", chainId: signatureChainId)
        let typeText = "\(primaryType)(\(fields.map(\.declaration).joined(separator: ",")))"
        var encoded = keccak(Array(typeText.utf8))
        for field in fields {
            encoded += try field.encoded()
        }
        return keccak([0x19, 0x01] + domain + keccak(encoded))
    }

    package static func keccak(_ bytes: [UInt8]) -> [UInt8] {
        SHA3(variant: .keccak256).calculate(for: bytes)
    }

    /// An address's 20 bytes from its hex text, with or without "0x", in either case
    package static func addressBytes(_ address: String) throws -> [UInt8] {
        let hex = address.hasPrefix("0x") || address.hasPrefix("0X") ? String(address.dropFirst(2)) : address
        let bytes = [UInt8](hex: hex)
        guard hex.count == 40, bytes.count == 20, hex.allSatisfy(\.isHexDigit) else {
            throw ExchangeClientError.malformedAddress(address)
        }
        return bytes
    }

    private static func domainSeparator(name: String, chainId: UInt64) -> [UInt8] {
        let type = keccak(Array("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)".utf8))
        return keccak(type + keccak(Array(name.utf8)) + keccak(Array("1".utf8)) + word(chainId) + [UInt8](repeating: 0, count: 32))
    }

    private static func word(_ number: UInt64) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 24)
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: number >> UInt64(shift)))
        }
        return bytes
    }
}
