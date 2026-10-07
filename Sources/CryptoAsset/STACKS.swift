// STACKS.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into STACKS+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `stacks` namespace of CAIP-2: Stacks's networks, each by its chain id
public enum STACKS {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "stacks"

    /// Stacks mainnet, `stacks:1`
    public enum Stacks {
        /// The chain's CAIP-2 id
        public static let chainId = STACKS.namespace + ":" + "1"

        /// STX, the chain's coin, at 6 decimals (microSTX), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let stx: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "stx"),
            decimals: 6,
            symbol: AssetSymbol(validating: "STX")
        )
    }
}
