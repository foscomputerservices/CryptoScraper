// CosmosHubContract+Addresses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

// The address shapes the Cosmos chains share, read by each Cosmos chain's own contract (`cosmos`, design § 2.5).
extension CosmosHubContract {
    /// Whether `text` is an account of the chain whose bech32 human-readable part is `humanReadablePart`: lower
    /// case, `<hrp>1`, then 38 characters of bech32's alphabet (a 20-byte account) or 58 (a 32-byte one, a CosmWasm
    /// contract or a module's derived account)
    ///
    /// The bech32 checksum is not verified; an upper-case address, which BIP 173 allows, is refused, since lower case
    /// is the form the chains write.
    static func isAccount(_ text: some StringProtocol, humanReadablePart: String) -> Bool {
        let prefix = humanReadablePart + "1"
        guard text.hasPrefix(prefix) else {
            return false
        }
        let data = text.dropFirst(prefix.count)
        return (data.count == 38 || data.count == 58)
            && data.allSatisfy { BitcoinContract.bech32Alphabet.contains($0) }
    }

    /// Whether `text` is an IBC denom, a token another chain sent over IBC: `ibc/` and 64 upper-case hex digits, the
    /// SHA-256 of its trace as the Cosmos SDK writes it
    static func isIBCDenom(_ text: String) -> Bool {
        let prefix = "ibc/"
        guard text.hasPrefix(prefix) else {
            return false
        }
        let hash = text.dropFirst(prefix.count)
        return hash.count == 64 && hash.allSatisfy { $0.isHexDigit && !$0.isLowercase }
    }
}
