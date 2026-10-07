// BIP122.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into BIP122+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `bip122` namespace of CAIP-2: the Bitcoin-family chains, each by its genesis block's hash, and the instances
/// declared on each
public enum BIP122 {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "bip122"

    /// Bitcoin mainnet, by the first 32 hex digits of its genesis block's hash
    public enum Bitcoin {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "000000000019d6689c085ae165831e93"

        /// Bitcoin, the chain's coin, at 8 decimals
        public static let btc: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "btc"),
            decimals: 8,
            symbol: AssetSymbol(validating: "BTC")
        )
    }

    /// Litecoin mainnet, by the first 32 hex digits of its genesis block's hash, as the bip122 namespace lists it
    public enum Litecoin {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "12a765e31ffd4059bada1e25190f6e98"

        /// Litecoin, the chain's coin, at 8 decimals (litoshi), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let ltc: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ltc"),
            decimals: 8,
            symbol: AssetSymbol(validating: "LTC")
        )
    }

    /// Dogecoin mainnet, by the first 32 hex digits of its genesis block's hash, as the bip122 namespace lists it
    public enum Dogecoin {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "1a91e3dace36e2be3bf030a65679fe82"

        /// Dogecoin, the chain's coin, at 8 decimals (koinu), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let doge: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "doge"),
            decimals: 8,
            symbol: AssetSymbol(validating: "DOGE")
        )
    }

    /// Bitcoin Cash mainnet, by the first 32 hex digits of the hash of its first block, 478559, where it forked from
    /// Bitcoin, as the bip122 namespace lists it (its genesis block is Bitcoin's)
    public enum BitcoinCash {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "000000000000000000651ef99cb9fcbe"

        /// Bitcoin Cash, the chain's coin, at 8 decimals (satoshi), under the placeholder address CryptoScraper's chain
        /// gives it
        public static let bch: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "bch"),
            decimals: 8,
            symbol: AssetSymbol(validating: "BCH")
        )
    }

    /// Dash mainnet, by the first 32 hex digits of its genesis block's hash (dashpay/dash `src/chainparams.cpp`), the
    /// bip122 namespace's form of a chain id; the namespace's registry does not list it
    public enum Dash {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "00000ffd590b1485b3caadc19b22e637"

        /// Dash, the chain's coin, at 8 decimals (duff), under the placeholder address CryptoScraper's chain gives it
        public static let dash: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "dash"),
            decimals: 8,
            symbol: AssetSymbol(validating: "DASH")
        )
    }

    /// DigiByte mainnet, by the first 32 hex digits of its genesis block's hash (DigiByte-Core/digibyte
    /// `src/kernel/chainparams.cpp`), the bip122 namespace's form of a chain id; the namespace's registry does not list
    /// it
    public enum DigiByte {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "7497ea1b465eb39f1c8f507bc877078f"

        /// DigiByte, the chain's coin, at 8 decimals (its count, which DigiByte names not), under the placeholder
        /// address CryptoScraper's chain gives it
        public static let dgb: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "dgb"),
            decimals: 8,
            symbol: AssetSymbol(validating: "DGB")
        )
    }

    /// Ravencoin mainnet, by the first 32 hex digits of its genesis block's hash (RavenProject/Ravencoin
    /// `src/chainparams.cpp`), the bip122 namespace's form of a chain id; the namespace's registry does not list it
    public enum Ravencoin {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "0000006b444bc2f2ffe627be9d9e7e7a"

        /// Ravencoin, the chain's coin, at 8 decimals (its count, which Ravencoin names not), under the placeholder
        /// address CryptoScraper's chain gives it
        public static let rvn: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "rvn"),
            decimals: 8,
            symbol: AssetSymbol(validating: "RVN")
        )
    }

    /// Zcash mainnet, by the first 32 hex digits of its genesis block's hash (zcash/zcash `src/chainparams.cpp`), the
    /// bip122 namespace's form of a chain id; the namespace's registry does not list it
    public enum Zcash {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "00040fe8ec8471911baa1db1266ea15d"

        /// Zcash, the chain's coin, at 8 decimals (zatoshi), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let zec: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "zec"),
            decimals: 8,
            symbol: AssetSymbol(validating: "ZEC")
        )
    }

    /// Verge mainnet, by the first 32 hex digits of its genesis block's hash (vergecurrency/verge
    /// `src/chainparams.cpp`), the bip122 namespace's form of a chain id; the namespace's registry does not list it
    public enum Verge {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "00000fc63692467faeb20cdb3b53200d"

        /// Verge, the chain's coin, at 6 decimals (Verge's `COIN` is 1,000,000, `src/amount.h`; its count, which Verge
        /// names not), under the placeholder address CryptoScraper's chain gives it
        public static let xvg: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "xvg"),
            decimals: 6,
            symbol: AssetSymbol(validating: "XVG")
        )
    }

    /// Qtum mainnet, by the first 32 hex digits of its genesis block's hash (qtumproject/qtum
    /// `src/kernel/chainparams.cpp`), the bip122 namespace's form of a chain id; the namespace's registry does not list
    /// it
    public enum Qtum {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "000075aef83cf2853580f8ae8ce6f8c3"

        /// Qtum, the chain's coin, at 8 decimals (its count, which Qtum names not), under the placeholder address
        /// CryptoScraper's chain gives it
        public static let qtum: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "qtum"),
            decimals: 8,
            symbol: AssetSymbol(validating: "QTUM")
        )
    }

    /// eCash mainnet, by the first 32 hex digits of the hash of its first block, 661648, where it split from Bitcoin Cash (Bitcoin ABC's `axionHeight` is 661647; the hash read once from chronik, eCash's indexer), the bip122 namespace's form of a chain id, as the namespace lists Bitcoin Cash's; the registry does not list it (its genesis block is Bitcoin's)
    public enum ECash {
        /// The chain's CAIP-2 id
        public static let chainId = BIP122.namespace + ":" + "000000000000000004284c9d8b2c8ff7"

        /// XEC, the chain's coin, at 2 decimals (satoshi: Bitcoin ABC's `XEC` currency is 100 satoshis, 2 decimals), under the placeholder address CryptoScraper's chain gives it
        public static let xec: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "xec"),
            decimals: 2,
            symbol: AssetSymbol(validating: "XEC")
        )
    }
}
