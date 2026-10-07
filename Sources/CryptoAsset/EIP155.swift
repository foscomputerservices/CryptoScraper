// EIP155.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into EIP155+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `eip155` namespace of CAIP-2: the EVM chains, each by its chain id, and the instances declared on each
public enum EIP155 {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "eip155"

    /// Ethereum mainnet, `eip155:1`
    public enum Ethereum {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":1"

        /// Ether, the chain's coin, at 18 decimals
        public static let eth: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "eth"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ETH")
        )

        /// USD Coin's contract: the generated ``usdCoin``, CoinGecko's `usd-coin`, by the name `Asset.usdc` gives it
        public static var usdc: AssetDeclaration.Instance { usdCoin }

        /// Tether's contract: the generated ``tether``, CoinGecko's `tether`, by the name `Asset.usdt` gives it
        public static var usdt: AssetDeclaration.Instance { tether }
    }

    /// BNB Smart Chain, `eip155:56`
    public enum BinanceSmartChain {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":56"

        /// BNB, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let bnb: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "bnb"),
            decimals: 18,
            symbol: AssetSymbol(validating: "BNB")
        )
    }

    /// Polygon PoS, `eip155:137`
    public enum Polygon {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":137"

        /// POL, the chain's coin (MATIC until its rename), at 18 decimals, under the placeholder address
        /// CryptoScraper's chain gives it, "matic"
        public static let pol: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "matic"),
            decimals: 18,
            symbol: AssetSymbol(validating: "POL")
        )
    }

    /// Optimism, `eip155:10`
    public enum Optimism {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":10"

        /// Ether on Optimism, the chain's coin, at 18 decimals: an instance of Ethereum's ether, not an asset of its
        /// own
        public static let eth: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "eth"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ETH")
        )
    }

    /// Fantom Opera, `eip155:250`
    public enum Fantom {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":250"

        /// FTM, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let ftm: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ftm"),
            decimals: 18,
            symbol: AssetSymbol(validating: "FTM")
        )
    }

    /// Avalanche C-Chain, `eip155:43114`
    public enum Avalanche {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":43114"

        /// AVAX, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let avax: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "avax"),
            decimals: 18,
            symbol: AssetSymbol(validating: "AVAX")
        )
    }

    /// Ethereum Classic, `eip155:61`
    public enum EthereumClassic {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":61"

        /// ETC, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let etc: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "etc"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ETC")
        )
    }

    /// Celo, `eip155:42220`
    public enum Celo {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":42220"

        /// CELO, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let celo: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "celo"),
            decimals: 18,
            symbol: AssetSymbol(validating: "CELO")
        )
    }

    /// Base, `eip155:8453`
    public enum Base {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":8453"

        /// Ether on Base, the chain's coin, at 18 decimals: an instance of Ethereum's ether, not an asset of its own
        public static let eth: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "eth"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ETH")
        )
    }

    /// Theta's EVM chain, `eip155:361`, whose coin is TFUEL; THETA, on Theta's separate mainchain, is not this chain's
    public enum Theta {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":361"

        /// TFUEL (Theta Fuel), the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain
        /// gives it
        public static let tfuel: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "tfuel"),
            decimals: 18,
            symbol: AssetSymbol(validating: "TFUEL")
        )
    }

    /// COTI, `eip155:2632500`
    public enum COTI {
        /// The chain's CAIP-2 id
        public static let chainId = EIP155.namespace + ":2632500"

        /// COTI, the chain's coin, at 18 decimals, under the placeholder address CryptoScraper's chain gives it
        public static let coti: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "coti"),
            decimals: 18,
            symbol: AssetSymbol(validating: "COTI")
        )
    }
}
