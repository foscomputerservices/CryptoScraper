// MINA.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into MINA+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `mina` namespace of CAIP-2: Mina's networks, `mainnet`, `devnet`
public enum MINA {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "mina"

    /// Mina mainnet, `mina:mainnet`
    public enum Mina {
        /// The chain's CAIP-2 id
        public static let chainId = MINA.namespace + ":" + "mainnet"

        /// MINA, the chain's coin, at 9 decimals (nanomina), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let mina: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "mina"),
            decimals: 9,
            symbol: AssetSymbol(validating: "MINA")
        )
    }
}
