// HEDERA.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into HEDERA+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `hedera` namespace of CAIP-2: Hedera's networks, `mainnet`, `testnet`, `previewnet`, `devnet`
public enum HEDERA {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "hedera"

    /// Hedera mainnet, `hedera:mainnet`
    public enum Hedera {
        /// The chain's CAIP-2 id
        public static let chainId = HEDERA.namespace + ":" + "mainnet"

        /// HBAR, the chain's coin, at 8 decimals (tinybars), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let hbar: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "hbar"),
            decimals: 8,
            symbol: AssetSymbol(validating: "HBAR")
        )
    }
}
