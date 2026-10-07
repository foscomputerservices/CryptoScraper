// FLOW.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into FLOW+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `flow` namespace of CAIP-2: Flow's networks, `mainnet`, `testnet`
public enum FLOW {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "flow"

    /// Flow mainnet, `flow:mainnet`
    public enum Flow {
        /// The chain's CAIP-2 id
        public static let chainId = FLOW.namespace + ":" + "mainnet"

        /// FLOW, the chain's coin, at 8 decimals (its count, which Flow names not), under the placeholder address
        /// CryptoScraper's chain gives it
        public static let flow: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "flow"),
            decimals: 8,
            symbol: AssetSymbol(validating: "FLOW")
        )
    }
}
