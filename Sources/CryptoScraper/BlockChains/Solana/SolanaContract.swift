// SolanaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Solana: an account or a token's mint, base58 of 32 bytes, kept as given (base58 is case-sensitive)
public struct SolanaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Solana's ladder: lamports to SOL, the base unit at exponent 0 and the chain's coin at 9
    public enum Units: String, CurrencyUnits {
        case lamport
        case sol

        public static var chainBaseUnits: Self { .lamport }
        public static var defaultDisplayUnits: Self { .sol }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = SolanaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``SolanaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension SolanaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension SolanaContract {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.address = try container.decode(String.self, forKey: .address)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(address, forKey: .address)
    }

    private enum CodingKeys: String, CodingKey {
        case address
    }
}

public extension SolanaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 9 for SOL
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "SOL" for the whole unit, "SOL(lamport)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .sol
            ? "SOL"
            : "SOL(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 9 digits in SOL
    var displayFractionDigits: Int { exponent }
}

private extension SolanaContract.Units {
    var exponent: Int {
        switch self {
        case .lamport: return 0
        case .sol: return 9
        }
    }
}

extension SolanaContract {
    /// Whether `address` is base58 (Bitcoin's alphabet, as Solana writes it) of exactly 32 bytes
    static func isWellFormed(_ address: String) -> Bool {
        (32...44).contains(address.count) && base58ByteCount(address) == 32
    }

    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    // The number of bytes `text` decodes to as base58, `nil` when a character is outside the alphabet; each leading
    // "1" is one leading zero byte.
    private static func base58ByteCount(_ text: String) -> Int? {
        var bytes: [UInt8] = []
        for character in text {
            guard var carry = alphabet.firstIndex(of: character) else {
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
        return leadingZeros + bytes.drop { $0 == 0 }.count
    }
}
