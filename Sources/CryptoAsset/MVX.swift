// MVX.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into MVX+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `mvx` namespace of CAIP-2: MultiversX's networks, each by its chain id, `1` for mainnet
public enum MVX {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "mvx"

    /// MultiversX mainnet, `mvx:1`
    public enum MultiversX {
        /// The chain's CAIP-2 id
        public static let chainId = MVX.namespace + ":" + "1"

        /// EGLD, the chain's coin, at 18 decimals (its atomic units, which MultiversX names not), under the placeholder
        /// address CryptoScraper's chain gives it
        public static let egld: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "egld"),
            decimals: 18,
            symbol: AssetSymbol(validating: "EGLD")
        )
    }
}
