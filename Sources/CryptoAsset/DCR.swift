// DCR.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into DCR+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `dcr` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: Decred's networks, each by name (Decred's block header is not Bitcoin's, so it is not `bip122`)
public enum DCR {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "dcr"

    /// Decred mainnet, `dcr:mainnet`
    public enum Decred {
        /// The chain's CAIP-2 id
        public static let chainId = DCR.namespace + ":" + "mainnet"

        /// DCR, the chain's coin, at 8 decimals (atoms), under the placeholder address CryptoScraper's chain gives it
        public static let dcr: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "dcr"),
            decimals: 8,
            symbol: AssetSymbol(validating: "DCR")
        )
    }
}
