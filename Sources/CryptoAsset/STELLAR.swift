// STELLAR.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into STELLAR+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `stellar` namespace of CAIP-2: Stellar's networks, `pubnet` and `testnet`
public enum STELLAR {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "stellar"

    /// Stellar's public network, `stellar:pubnet`
    public enum Stellar {
        /// The chain's CAIP-2 id
        public static let chainId = STELLAR.namespace + ":" + "pubnet"

        /// XLM (lumens), the chain's coin, at 7 decimals (stroops), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let xlm: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "xlm"),
            decimals: 7,
            symbol: AssetSymbol(validating: "XLM")
        )
    }
}
