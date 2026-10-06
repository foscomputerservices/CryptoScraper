// SigningVectors.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoHyperliquid
import Foundation

// The fixture of poc/harness/hyperliquid-signing-vectors.ts (fosline 67d4ede), copied here unchanged as
// Resources/hyperliquid-signing-vectors.json: its first line, the key "origin", names the script and the date.

struct VectorFile: Decodable {
    let origin: String
    let agentPrivateKeyHex: String
    let agentAddress: String
    let vectors: [L1Vector]
    let userSignedVectors: [UserSignedVector]

    static let loaded: VectorFile = {
        let url = Bundle.module.url(forResource: "hyperliquid-signing-vectors", withExtension: "json")!
        return try! JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
    }()

    var key: HyperliquidAgentKey {
        try! HyperliquidAgentKey(privateKey: Data(hexText: agentPrivateKeyHex))
    }
}

struct L1Vector: Decodable, Sendable, CustomStringConvertible {
    let name: String
    let actionJSON: String
    let actionMsgpackHex: String
    let nonce: UInt64
    let isMainnet: Bool
    let vaultAddress: String?
    let actionHashHex: String
    let typedDataHashHex: String
    let r: String
    let s: String
    let v: Int

    var description: String { name }
}

struct UserSignedVector: Decodable, Sendable, CustomStringConvertible {
    let name: String
    let actionJSON: String
    let primaryType: String
    let isMainnet: Bool
    let typedDataHashHex: String
    let r: String
    let s: String
    let v: Int

    var description: String { name }
}

extension Data {
    init(hexText: String) {
        let digits = Array(hexText.hasPrefix("0x") ? hexText.dropFirst(2) : Substring(hexText))
        self.init(stride(from: 0, to: digits.count, by: 2).map { UInt8(String(digits[$0..<$0 + 2]), radix: 16)! })
    }
}

func hexText(_ bytes: [UInt8]) -> String {
    "0x" + bytes.map { String(format: "%02x", $0) }.joined()
}

// An ordered reading of a JSON text into the action value, keys in the text's order, so a fixture's action can be
// encoded as the exchange hashes it. Strings, integers, booleans, null, arrays and objects: what an action holds.
enum OrderedJSON {
    static func parse(_ text: String) -> HyperliquidWireValue {
        var scalars = Array(text.unicodeScalars)[...]
        return value(&scalars)
    }

    private static func skipSpace(_ s: inout ArraySlice<Unicode.Scalar>) {
        while let c = s.first, c == " " || c == "\n" || c == "\t" || c == "\r" { s.removeFirst() }
    }

    private static func value(_ s: inout ArraySlice<Unicode.Scalar>) -> HyperliquidWireValue {
        skipSpace(&s)
        switch s.first! {
        case "{":
            s.removeFirst()
            var entries: [(String, HyperliquidWireValue)] = []
            skipSpace(&s)
            if s.first == "}" { s.removeFirst(); return .map([]) }
            while true {
                skipSpace(&s)
                let key = string(&s)
                skipSpace(&s); s.removeFirst() // ":"
                entries.append((key, value(&s)))
                skipSpace(&s)
                if s.removeFirst() == "}" { return .map(entries) }
            }
        case "[":
            s.removeFirst()
            var items: [HyperliquidWireValue] = []
            skipSpace(&s)
            if s.first == "]" { s.removeFirst(); return .array([]) }
            while true {
                items.append(value(&s))
                skipSpace(&s)
                if s.removeFirst() == "]" { return .array(items) }
            }
        case "\"":
            return .string(string(&s))
        case "t":
            s.removeFirst(4); return .bool(true)
        case "f":
            s.removeFirst(5); return .bool(false)
        case "n":
            s.removeFirst(4); return .null
        default:
            var digits = ""
            while let c = s.first, c == "-" || ("0"..."9").contains(c) { digits.unicodeScalars.append(s.removeFirst()) }
            return .integer(Int64(digits)!)
        }
    }

    private static func string(_ s: inout ArraySlice<Unicode.Scalar>) -> String {
        s.removeFirst() // the opening quote
        var out = ""
        while let c = s.first {
            s.removeFirst()
            if c == "\"" { return out }
            if c == "\\" {
                let escaped = s.removeFirst()
                switch escaped {
                case "n": out += "\n"
                case "t": out += "\t"
                case "r": out += "\r"
                default: out.unicodeScalars.append(escaped)
                }
            } else {
                out.unicodeScalars.append(c)
            }
        }
        return out
    }
}
