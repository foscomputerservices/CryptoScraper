// ARWEAVE.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into ARWEAVE+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `arweave` namespace of CAIP-2: Arweave's networks, each by the first characters of its genesis block's hash
public enum ARWEAVE {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "arweave"

    /// Arweave mainnet, `arweave:7wIU`
    public enum Arweave {
        /// The chain's CAIP-2 id
        public static let chainId = ARWEAVE.namespace + ":" + "7wIU"

        /// AR, the chain's coin, at 12 decimals (winston), under the placeholder address CryptoScraper's chain gives it
        public static let ar: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ar"),
            decimals: 12,
            symbol: AssetSymbol(validating: "AR")
        )
    }
}
