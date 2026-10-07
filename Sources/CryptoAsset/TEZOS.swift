// TEZOS.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into TEZOS+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `tezos` namespace of CAIP-2: Tezos's networks, each by its chain id
public enum TEZOS {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "tezos"

    /// Tezos mainnet, `tezos:NetXdQprcVkpaWU`
    public enum Tezos {
        /// The chain's CAIP-2 id
        public static let chainId = TEZOS.namespace + ":" + "NetXdQprcVkpaWU"

        /// XTZ (tez), the chain's coin, at 6 decimals (mutez), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let xtz: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "xtz"),
            decimals: 6,
            symbol: AssetSymbol(validating: "XTZ")
        )
    }
}
