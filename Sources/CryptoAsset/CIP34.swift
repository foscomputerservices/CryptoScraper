// CIP34.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into CIP34+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `cip34` namespace, CIP-34's own proposal for a CAIP-2 namespace, which CAIP's registry does not hold
/// (2026-10-07), so the library owns it until CAIP registers one: Cardano's networks, each by its CIP-34 reference, the
/// network id and the network magic
public enum CIP34 {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "cip34"

    /// Cardano mainnet, `cip34:1-764824073`, by its CIP-34 reference: network id 1, network magic 764824073
    public enum Cardano {
        /// The chain's CAIP-2 id
        public static let chainId = CIP34.namespace + ":" + "1-764824073"

        /// ADA, the chain's coin, at 6 decimals (lovelace), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let ada: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ada"),
            decimals: 6,
            symbol: AssetSymbol(validating: "ADA")
        )
    }
}
