// XRPL.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into XRPL+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `xrpl` namespace of CAIP-2: the XRP Ledger's networks, each by its network id
public enum XRPL {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "xrpl"

    /// The XRP Ledger's mainnet, `xrpl:0`
    public enum XRPLedger {
        /// The chain's CAIP-2 id
        public static let chainId = XRPL.namespace + ":" + "0"

        /// XRP, the chain's coin, at 6 decimals (drops), under the placeholder address CryptoScraper's chain gives it
        public static let xrp: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "xrp"),
            decimals: 6,
            symbol: AssetSymbol(validating: "XRP")
        )
    }
}
