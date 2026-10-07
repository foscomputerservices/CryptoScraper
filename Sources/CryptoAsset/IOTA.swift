// IOTA.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into IOTA+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `iota` namespace of CAIP-2: the Move-based IOTA's networks, `mainnet`, `testnet`, `devnet`
public enum IOTA {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "iota"

    /// IOTA mainnet, `iota:mainnet`, the Move-based ledger of 2025
    public enum Iota {
        /// The chain's CAIP-2 id
        public static let chainId = IOTA.namespace + ":" + "mainnet"

        /// IOTA, the chain's coin, at 9 decimals (nanos), under the placeholder address CryptoScraper's chain gives it
        public static let iota: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "iota"),
            decimals: 9,
            symbol: AssetSymbol(validating: "IOTA")
        )
    }
}
