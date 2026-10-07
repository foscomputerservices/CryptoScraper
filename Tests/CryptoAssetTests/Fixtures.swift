// Fixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// Values every suite shares, each built through the public path only.

enum Fixtures {
    /// The CAIP namespaces registry's namespace folders, recorded 2026-10-07 from
    /// https://github.com/ChainAgnostic/namespaces (the identity reading's verification, and the repository's root
    /// listing that day). The root holds 55 folders: these 49 namespaces, and .github, _data, _includes, _layouts,
    /// _template and assets, which name no namespace.
    static let caipNamespaces: Set<String> = [
        "acknacki", "aleo", "alephium", "algorand", "antelope", "aptos", "arweave", "avalanche", "bip122", "bsv",
        "casper", "ccd", "chia", "conflux", "cosmos", "eip155", "ergo", "fil", "flow", "haneul",
        "hedera", "hive", "iota", "klv", "koinos", "mina", "monero", "mvx", "neo", "partisia",
        "polkadot", "quai", "qubic", "reef", "solana", "stacks", "starknet", "stellar", "sui", "swift",
        "tenzro", "tezos", "tron", "tvm", "vechain", "wallet", "waves", "xrpl", "xync"
    ]

    static func instance(_ id: String) -> AssetInstance {
        do {
            return try AssetInstance(validating: id)
        } catch {
            preconditionFailure("Fixtures.instance(\(id)): \(error)")
        }
    }

    // The five well-known assets' home instances, read from the library's own statics.
    static let usd = instance(Asset.usd.id)
    static let usdc = instance(Asset.usdc.id)
    static let usdt = instance(Asset.usdt.id)
    static let btc = instance(Asset.btc.id)
    static let eth = instance(Asset.eth.id)

    // Each a reserved fake on the bedrock:42 chain, declared below at its decimals.
    static let snek = instance("bedrock:42:snek")              // a whole-unit token, as SNEK is: decimals 0
    static let cheap = instance("bedrock:42:cheap")            // an 18-decimal cheap token, the headroom table's last row
    static let flat = instance("bedrock:42:flat")              // decimals 0, so a price's scaled number reads plainly
    static let thirty = instance("bedrock:42:thirty")          // decimals 30, the widest
    static let twentyNine = instance("bedrock:42:twenty-nine") // decimals 29

    // Exchange holdings and other chains' contracts, declared in the tests' own registries (design § 6: each test
    // builds its own). In step 2 no library declaration names an exchange holding: each plug-in declares its own in
    // step 4, under the owner's strings rule.
    static let binanceUSDT = instance("exchange:binance:USDT")
    static let krakenXBT = instance("exchange:kraken:XBT")
    static let krakenUSD = instance("exchange:kraken:USD")
    static let coinbaseUSD = instance("exchange:coinbase:USD")
    static let hyperliquidUSDC = instance("exchange:hyperliquid:USDC")
    static let hyperliquidBTC = instance("exchange:hyperliquid:BTC")
    static let bscUSDC = instance("eip155:56:0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d")
    static let polygonUSDC = instance("eip155:137:0x3c499c542cef5e3811e1192ce70d8cc03d5c3359")

    static func holding(_ instance: AssetInstance, decimals: Int, symbol: String) -> AssetDeclaration.Instance {
        do {
            return try AssetDeclaration.Instance(instance: instance, decimals: decimals, symbol: AssetSymbol(validating: symbol))
        } catch {
            preconditionFailure("Fixtures.holding(\(instance.id)): \(error)")
        }
    }

    /// The library's declaration of `asset`, its instances followed by `more`
    static func libraryDeclaration(of asset: Asset, adding more: [AssetDeclaration.Instance]) -> AssetDeclaration {
        let declared = libraryDeclaration(of: asset)
        do {
            return try AssetDeclaration(
                asset: declared.asset, tokenName: declared.tokenName, symbol: declared.symbol,
                aggregatorId: declared.aggregatorId,
                wholeUnit: .init(name: declared.wholeUnit.name, symbol: declared.wholeUnit.symbol,
                                 fractionDigits: declared.wholeUnit.fractionDigits),
                baseUnit: declared.baseUnit.map { .init(name: $0.name, symbol: $0.symbol, fractionDigits: $0.fractionDigits) },
                between: declared.between, displayUnit: declared.displayUnit,
                instances: declared.instances + more
            )
        } catch {
            preconditionFailure("Fixtures.libraryDeclaration(of:adding:): \(error)")
        }
    }

    /// The five assets with the holdings the design's tests name: Binance's tether at 8, Kraken's XBT at 10 and its
    /// dollar at 4, Coinbase's dollar at 2, Hyperliquid's USDC at 6 and BTC at 5, USDC on BNB Smart Chain and Polygon
    static func declarationsWithHoldings() -> [AssetDeclaration] {
        [
            libraryDeclaration(of: .usd, adding: [
                holding(krakenUSD, decimals: 4, symbol: "USD"),
                holding(coinbaseUSD, decimals: 2, symbol: "USD")
            ]),
            libraryDeclaration(of: .usdc, adding: [
                holding(bscUSDC, decimals: 18, symbol: "USDC"),
                holding(polygonUSDC, decimals: 6, symbol: "USDC"),
                holding(hyperliquidUSDC, decimals: 6, symbol: "USDC")
            ]),
            libraryDeclaration(of: .usdt, adding: [holding(binanceUSDT, decimals: 8, symbol: "USDT")]),
            libraryDeclaration(of: .btc, adding: [
                holding(krakenXBT, decimals: 10, symbol: "XBT"),
                holding(hyperliquidBTC, decimals: 5, symbol: "BTC")
            ]),
            libraryDeclaration(of: .eth)
        ]
    }

    static func registryWithHoldings() -> AssetRegistry {
        do {
            return try AssetRegistry(declarationsWithHoldings())
        } catch {
            preconditionFailure("Fixtures.registryWithHoldings(): \(error)")
        }
    }

    static func declaration(_ instance: AssetInstance, decimals: Int, symbol: String) -> AssetDeclaration {
        do {
            let symbol = try AssetSymbol(validating: symbol)
            return try AssetDeclaration(
                asset: Asset(validating: instance.id), tokenName: symbol.text, symbol: symbol,
                instances: [.init(instance: instance, decimals: decimals, symbol: symbol)]
            )
        } catch {
            preconditionFailure("Fixtures.declaration(\(instance.id)): \(error)")
        }
    }

    static let fakeDeclarations: [AssetDeclaration] = [
        declaration(snek, decimals: 0, symbol: "SNEK"),
        declaration(cheap, decimals: 18, symbol: "CHEAP"),
        declaration(flat, decimals: 0, symbol: "FLAT"),
        declaration(thirty, decimals: 30, symbol: "THIRTY"),
        declaration(twentyNine, decimals: 29, symbol: "TWENTYNINE")
    ]

    /// A registry of the library's declarations and the fakes, made fresh for each caller
    static func registry() -> AssetRegistry {
        do {
            return try AssetRegistry(AssetRegistry.libraryDeclarations + fakeDeclarations)
        } catch {
            preconditionFailure("Fixtures.registry(): \(error)")
        }
    }

    static func libraryDeclaration(of asset: Asset) -> AssetDeclaration {
        AssetRegistry.libraryDeclarations.first { $0.asset == asset }!
    }

    static let satoshi = libraryDeclaration(of: .btc).unit(named: "satoshi")!
    static let bitcoin = libraryDeclaration(of: .btc).unit(named: "bitcoin")!
    static let wei = libraryDeclaration(of: .eth).unit(named: "wei")!
    static let gwei = Asset.Unit(name: "gwei", exponent: 9)
    static let ether = libraryDeclaration(of: .eth).unit(named: "ether")!
    static let cent = libraryDeclaration(of: .usd).unit(named: "cent")!
    static let dollar = libraryDeclaration(of: .usd).unit(named: "dollar")!

    static let tenToThe30: Int128 = 1_000_000_000_000_000_000_000_000_000_000
    static let tenToThe9: Int128 = 1_000_000_000

    static let extremes: [Int128] = [.max, .min, tenToThe30]

    // A Fraction whose scaled numerator is exactly `numerator`, made through the public path:
    // numerator over 10^9 base units of one instance.
    static func fraction(atScaled numerator: Int128) -> Fraction {
        Fraction(Amount(baseUnits: numerator, of: usd), over: Amount(baseUnits: tenToThe9, of: usd))
    }

    // A Price whose scaled number is exactly `numerator` USD base units: numerator for 10^9 of a 0-decimal instance.
    static func price(atScaled numerator: Int128, in registry: AssetRegistry = registry()) -> Price {
        do {
            return try Price(Amount(baseUnits: numerator, of: usd), per: Amount(baseUnits: tenToThe9, of: flat), in: registry)
        } catch {
            preconditionFailure("Fixtures.price(atScaled:): \(error)")
        }
    }
}
