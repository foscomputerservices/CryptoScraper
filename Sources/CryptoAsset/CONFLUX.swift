// CONFLUX.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into CONFLUX+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `conflux` namespace of CAIP-2: Conflux core space's networks, `cfx` for mainnet and `cfxtest`
public enum CONFLUX {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "conflux"

    /// Conflux core space mainnet, `conflux:cfx` (network id 1029); its eSpace is the EVM chain 1030
    public enum Conflux {
        /// The chain's CAIP-2 id
        public static let chainId = CONFLUX.namespace + ":" + "cfx"

        /// CFX, the chain's coin, at 18 decimals (drip), under the placeholder address CryptoScraper's chain gives it
        public static let cfx: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "cfx"),
            decimals: 18,
            symbol: AssetSymbol(validating: "CFX")
        )
    }
}
