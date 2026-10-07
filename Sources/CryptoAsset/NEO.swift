// NEO.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into NEO+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `neo` namespace of CAIP-2: Neo N3's networks, each by its Network Magic in decimal
public enum NEO {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "neo"

    /// Neo N3 MainNet, `neo:860833102`, by its Network Magic
    public enum Neo {
        /// The chain's CAIP-2 id
        public static let chainId = NEO.namespace + ":" + "860833102"

        /// NEO, the chain's coin, indivisible (0 decimals), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let neo: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "neo"),
            decimals: 0,
            symbol: AssetSymbol(validating: "NEO")
        )

        /// GAS, the chain's second native coin, at 8 decimals, under its own placeholder address, its own declaration
        /// (design § 2.5, "Two native coins on one chain")
        public static let gas: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "gas"),
            decimals: 8,
            symbol: AssetSymbol(validating: "GAS")
        )
    }
}
