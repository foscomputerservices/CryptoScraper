// NEAR.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into NEAR+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `near` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: NEAR Protocol's networks, each by its network id
public enum NEAR {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "near"

    /// NEAR Protocol mainnet, `near:mainnet`, by its network id
    public enum Near {
        /// The chain's CAIP-2 id
        public static let chainId = NEAR.namespace + ":" + "mainnet"

        /// NEAR, the chain's coin, at 24 decimals (yoctoNEAR), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let near: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "near"),
            decimals: 24,
            symbol: AssetSymbol(validating: "NEAR")
        )
    }
}
