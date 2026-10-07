// TRON.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into TRON+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `tron` namespace of CAIP-2: Tron's chains, each by its chain id in decimal
public enum TRON {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "tron"

    /// Tron mainnet, `tron:728126428` (0x2b6653dc in decimal, the namespace's registered form)
    public enum Tron {
        /// The chain's CAIP-2 id
        public static let chainId = TRON.namespace + ":728126428"

        /// TRX, the chain's coin, at 6 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let trx: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "TRX"),
            decimals: 6,
            symbol: AssetSymbol(validating: "TRX")
        )
    }
}
