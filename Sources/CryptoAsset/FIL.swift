// FIL.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into FIL+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `fil` namespace of CAIP-2: Filecoin's networks, `f` for mainnet and `t` for the test networks, by their
/// addresses' network prefix
public enum FIL {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "fil"

    /// Filecoin mainnet, `fil:f`
    public enum Filecoin {
        /// The chain's CAIP-2 id
        public static let chainId = FIL.namespace + ":" + "f"

        /// FIL, the chain's coin, at 18 decimals (attoFIL), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let fil: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "fil"),
            decimals: 18,
            symbol: AssetSymbol(validating: "FIL")
        )
    }
}
