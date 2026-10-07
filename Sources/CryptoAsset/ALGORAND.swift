// ALGORAND.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into ALGORAND+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `algorand` namespace of CAIP-2: Algorand's networks, each by the first 32 characters of its genesis hash
public enum ALGORAND {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "algorand"

    /// Algorand MainNet, `algorand:wGHE2Pwdvd7S12BL5FaOP20EGYesN73k`, by its genesis hash
    public enum Algorand {
        /// The chain's CAIP-2 id
        public static let chainId = ALGORAND.namespace + ":" + "wGHE2Pwdvd7S12BL5FaOP20EGYesN73k"

        /// ALGO, the chain's coin, at 6 decimals (microalgos), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let algo: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "algo"),
            decimals: 6,
            symbol: AssetSymbol(validating: "ALGO")
        )
    }
}
