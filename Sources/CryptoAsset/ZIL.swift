// ZIL.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into ZIL+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `zil` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: Zilliqa's networks, each by name (Zilliqa 2.0's EVM side is `eip155:32769`, another chain)
public enum ZIL {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "zil"

    /// Zilliqa mainnet, `zil:mainnet`
    public enum Zilliqa {
        /// The chain's CAIP-2 id
        public static let chainId = ZIL.namespace + ":" + "mainnet"

        /// ZIL, the chain's coin, at 12 decimals (Qa), under the placeholder address CryptoScraper's chain gives it
        public static let zil: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "zil"),
            decimals: 12,
            symbol: AssetSymbol(validating: "ZIL")
        )
    }
}
