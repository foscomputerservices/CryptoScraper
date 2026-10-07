// AssetImporter.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

/// The importer (design § 2.7): CoinGecko's answers in, the generated declarations' Swift source out
///
/// Pure over decoded answers; it touches no network and writes no file. The script that reads CoinGecko and writes
/// the files calls it.
///
/// - **The files:** one `<NAMESPACE>+Imported.swift` per namespace with admitted chains (`EIP155`, `BIP122`, `TRON`,
///   `SOLANA` and the rest, 29 in all),
///   an extension per admitted chain holding one `AssetDeclaration.Instance` per contract the coins have on it, and
///   `Assets+Imported.swift`, one `AssetDeclaration` per coin, its home first.
/// - **The chains:** only the library's admitted chains, the ones CryptoScraper has a conformer for, reached from
///   CoinGecko's platform ids through `AssetRegistry.referenceChainIds`. A contract on any other chain is left out
///   and counted.
/// - **The natives:** a chain's own coin (no platform) is the conformer's, never generated.
/// - **The names:** a constant's Swift name is the coin's CoinGecko id in lowerCamel, never its symbol. A name
///   already taken, by an earlier coin or a hand-written member, leaves the coin out and is reported.
/// - **The decimals:** a contract's chain's, where its scanner's recorded answer states them (`chainDecimals`), over
///   CoinGecko's `decimal_place`; a disagreement is reported (design § 4.1). A contract with neither, or with a
///   figure outside 0 through 30, is left out and reported.
/// - **Regeneration** adds and renames; it never changes an address or a decimals: given the files as last
///   generated, a changed address or decimals is refused and reported, a changed symbol regenerates the symbol only,
///   a new coin adds, and a constant the answer no longer lists is carried as it was.
///
/// ```swift
/// let (files, report) = AssetImporter.generate(coins: details, date: "2026-10-07", previous: lastFiles)
/// files["EIP155+Imported.swift"]       // the Swift source
/// report.counts["chainNotAdmitted"]    // how many contracts were on chains the library has no conformer for
/// ```
public enum AssetImporter {
    /// What the importer left out and why, and what it refused to change
    public struct Report: Hashable, Sendable {
        /// Every finding: each coin's, or each listed asset's, in the order they were read, then the refused changes
        public let findings: [Finding]

        /// How many findings of each kind, by ``AssetImporter/Finding/kind``
        public var counts: [String: Int] {
            findings.reduce(into: [:]) { $0[$1.kind, default: 0] += 1 }
        }
    }

    /// One thing the importer left out or refused, and why
    public enum Finding: Hashable, Sendable {
        /// A chain's own coin: the conformer's, declared by the library, never generated
        case native(coinId: String, instance: String)
        /// The coin's own platform is not an admitted chain (`nil`: a native coin of a chain the library lacks); the
        /// coin is left out
        case homeChainNotAdmitted(coinId: String, platform: String?)
        /// One contract on a platform that is not an admitted chain, left out
        case chainNotAdmitted(coinId: String, platform: String)
        /// One contract on an admitted chain whose decimals neither its chain's scanner (`chainDecimals`) nor
        /// CoinGecko states, or whose figure is outside 0 through 30, left out
        case noDecimals(coinId: String, platform: String)
        /// One contract on an admitted chain whose address cannot make an instance id, left out
        case malformedAddress(coinId: String, platform: String, address: String)
        /// The coin's symbol is not a well-formed `AssetSymbol`; the coin is left out
        case malformedSymbol(coinId: String, symbol: String)
        /// The coin has no instance on its own chain; the coin is left out
        case noInstance(coinId: String)
        /// The coin's Swift name is already taken, by an earlier coin or a hand-written member; the coin is left out
        case nameCollision(coinId: String, name: String, with: String)
        /// A generated constant's address differs from the one generated before; the change is refused, the old
        /// address kept
        case addressChanged(name: String, chainId: String, kept: String, refused: String)
        /// A generated constant's or exchange row's decimals differ from the ones generated before; the change is
        /// refused, the old decimals kept
        case decimalsChanged(name: String, chainId: String, kept: Int, refused: Int)
        /// An asset an exchange's listing states whose wire names CoinGecko's tickers on the exchange give no coin id,
        /// as a fiat quote; left out of the generated table, its row the exchange's overrides'
        case noCoinId(exchange: String, wireName: String)
        /// A generated row's class differs from the one generated before; the change is refused, the old class kept
        case classChanged(name: String, chainId: String, kept: String, refused: String)
        /// One contract whose decimals its chain's scanner states otherwise than CoinGecko (design § 4.1, the chain's
        /// scanner the oracle): the chain's decimals kept, CoinGecko's refused
        case decimalsDisagree(coinId: String, platform: String, kept: Int, refused: Int)

        /// The case's name, the key of ``AssetImporter/Report/counts``
        public var kind: String {
            switch self {
            case .native: "native"
            case .homeChainNotAdmitted: "homeChainNotAdmitted"
            case .chainNotAdmitted: "chainNotAdmitted"
            case .noDecimals: "noDecimals"
            case .malformedAddress: "malformedAddress"
            case .malformedSymbol: "malformedSymbol"
            case .noInstance: "noInstance"
            case .nameCollision: "nameCollision"
            case .addressChanged: "addressChanged"
            case .decimalsChanged: "decimalsChanged"
            case .noCoinId: "noCoinId"
            case .classChanged: "classChanged"
            case .decimalsDisagree: "decimalsDisagree"
            }
        }
    }

    /// The generated files' text, by file name, and the report
    ///
    /// - Parameters:
    ///   - coins: each coin's `/coins/{id}` answer, in the top's rank order; of two coins whose Swift names collide,
    ///     the later is left out
    ///   - date: the day the answers were read, "2026-10-07", written in each file's header
    ///   - previous: the files as last generated, by file name; empty on a first run
    ///   - chainDecimals: the decimals the admitted chains' scanners state for a contract, by chain id, then address
    ///     as CoinGecko writes it (design § 4.1, a token's decimals come from its chain's scanner, the oracle); a
    ///     contract's figure here is taken over CoinGecko's `decimal_place`, and a disagreement is reported. Empty:
    ///     CoinGecko's decimals alone
    public static func generate(
        coins: [CoinGeckoCoinResponse],
        date: String,
        previous: [String: String] = [:],
        chainDecimals: [String: [String: Int]] = [:]
    ) -> (files: [String: String], report: Report) {
        var findings: [Finding] = []
        let before = Previous(files: previous)

        // The coins this answer generates
        var fresh: [Declaration] = []
        var freshConstants: [Constant] = []
        var taken: [String: String] = before.declarations.reduce(into: [:]) { $0[$1.name] = $1.coinId }
        var takenNow: Set<String> = []

        for coin in coins {
            // An admitted chain's own coin is its conformer's, never generated, whatever home CoinGecko gives it
            if let native = nativeCoins[coin.id] {
                findings.append(.native(coinId: coin.id, instance: native.instance.id))
                continue
            }
            guard let platform = coin.assetPlatformId else {
                findings.append(.homeChainNotAdmitted(coinId: coin.id, platform: nil))
                continue
            }
            guard let home = admittedChain(platform: platform) else {
                findings.append(.homeChainNotAdmitted(coinId: coin.id, platform: platform))
                continue
            }
            guard let symbol = try? AssetSymbol(validating: coin.symbol) else {
                findings.append(.malformedSymbol(coinId: coin.id, symbol: coin.symbol))
                continue
            }

            let name = swiftName(coinId: coin.id)
            var contracts: [Constant] = []
            var contractFindings: [Finding] = []
            for platform in coin.detailPlatforms.keys.sorted() where !platform.isEmpty {
                let detail = coin.detailPlatforms[platform]!
                guard let chain = admittedChain(platform: platform) else {
                    contractFindings.append(.chainNotAdmitted(coinId: coin.id, platform: platform))
                    continue
                }
                // The chain's scanner states a token's decimals as the chain keeps them; CoinGecko's figure stands
                // only where no chain's is recorded (design § 4.1)
                let chains = chainDecimals[chain.chainId]?[detail.contractAddress]
                if let chains, let coinGeckos = detail.decimalPlace, chains != coinGeckos {
                    contractFindings.append(.decimalsDisagree(
                        coinId: coin.id, platform: platform, kept: chains, refused: coinGeckos
                    ))
                }
                guard let decimals = chains ?? detail.decimalPlace, (0...30).contains(decimals) else {
                    contractFindings.append(.noDecimals(coinId: coin.id, platform: platform))
                    continue
                }
                guard
                    !detail.contractAddress.isEmpty,
                    (try? AssetInstance(validating: chain.chainId + ":" + detail.contractAddress)) != nil
                else {
                    contractFindings.append(.malformedAddress(
                        coinId: coin.id, platform: platform, address: detail.contractAddress
                    ))
                    continue
                }
                contracts.append(Constant(
                    name: name, coinId: coin.id, coinName: coin.name, chain: chain,
                    address: detail.contractAddress, decimals: decimals, symbol: symbol.text
                ))
            }
            findings += contractFindings

            // Home first, then the admitted chains in the table's order
            contracts.sort { lhs, rhs in
                order(of: lhs.chain, home: home) < order(of: rhs.chain, home: home)
            }
            guard contracts.first?.chain == home else {
                findings.append(.noInstance(coinId: coin.id))
                continue
            }

            if reservedNames.contains(name) {
                let holder = name == "all" ? "Assets.all" : "the hand-written \(name)"
                findings.append(.nameCollision(coinId: coin.id, name: name, with: holder))
                continue
            }
            if let holder = taken[name], holder != coin.id || takenNow.contains(name) {
                findings.append(.nameCollision(coinId: coin.id, name: name, with: holder))
                continue
            }
            taken[name] = coin.id
            takenNow.insert(name)

            freshConstants += contracts
            fresh.append(Declaration(
                name: name, coinId: coin.id, tokenName: coin.name, symbol: symbol.text,
                instances: contracts.map { InstanceRef(chainPath: $0.chain.path, name: $0.name) }
            ))
        }

        // The constants: the ones generated before keep their place, their address and their decimals
        var constants = before.constants
        for constant in freshConstants {
            guard let index = constants.firstIndex(where: { $0.key == constant.key }) else {
                constants.append(constant)
                continue
            }
            let old = constants[index]
            var kept = constant
            if old.address != constant.address {
                findings.append(.addressChanged(
                    name: constant.name, chainId: constant.chain.chainId, kept: old.address, refused: constant.address
                ))
                kept.address = old.address
            }
            if old.decimals != constant.decimals {
                findings.append(.decimalsChanged(
                    name: constant.name, chainId: constant.chain.chainId, kept: old.decimals, refused: constant.decimals
                ))
                kept.decimals = old.decimals
            }
            constants[index] = kept
        }

        // The declarations: the ones generated before keep their place and their instances, new instances join them
        var declarations = before.declarations
        for declaration in fresh {
            guard let index = declarations.firstIndex(where: { $0.name == declaration.name }) else {
                declarations.append(declaration)
                continue
            }
            var kept = declaration
            kept.instances = declarations[index].instances
                + declaration.instances.filter { !declarations[index].instances.contains($0) }
            declarations[index] = kept
        }

        var files: [String: String] = [:]
        for namespace in namespaces {
            files["\(namespace)+Imported.swift"] = namespaceFile(namespace, constants: constants, date: date)
        }
        files[assetsFileName] = assetsFile(declarations, date: date)

        return (files, Report(findings: findings))
    }
}

// MARK: The tables

extension AssetImporter {
    /// One chain the library has a conformer for, with the Swift path of its generated enum
    struct AdmittedChain: Hashable, Sendable {
        let chainId: String
        let namespace: String
        let name: String

        var path: String { namespace + "." + name }
    }

    /// The library's admitted chains, in the order the generated files list them: CryptoScraper's, every chain of
    /// `BlockChains.knownBlockChains`
    static let admittedChains: [AdmittedChain] = [
        .init(chainId: EIP155.Ethereum.chainId, namespace: "EIP155", name: "Ethereum"),
        .init(chainId: EIP155.BinanceSmartChain.chainId, namespace: "EIP155", name: "BinanceSmartChain"),
        .init(chainId: EIP155.Polygon.chainId, namespace: "EIP155", name: "Polygon"),
        .init(chainId: EIP155.Optimism.chainId, namespace: "EIP155", name: "Optimism"),
        .init(chainId: EIP155.Fantom.chainId, namespace: "EIP155", name: "Fantom"),
        .init(chainId: EIP155.Avalanche.chainId, namespace: "EIP155", name: "Avalanche"),
        .init(chainId: EIP155.EthereumClassic.chainId, namespace: "EIP155", name: "EthereumClassic"),
        .init(chainId: EIP155.Celo.chainId, namespace: "EIP155", name: "Celo"),
        .init(chainId: EIP155.Base.chainId, namespace: "EIP155", name: "Base"),
        .init(chainId: EIP155.Theta.chainId, namespace: "EIP155", name: "Theta"),
        .init(chainId: EIP155.COTI.chainId, namespace: "EIP155", name: "COTI"),
        .init(chainId: BIP122.Bitcoin.chainId, namespace: "BIP122", name: "Bitcoin"),
        .init(chainId: BIP122.Litecoin.chainId, namespace: "BIP122", name: "Litecoin"),
        .init(chainId: BIP122.Dogecoin.chainId, namespace: "BIP122", name: "Dogecoin"),
        .init(chainId: BIP122.BitcoinCash.chainId, namespace: "BIP122", name: "BitcoinCash"),
        .init(chainId: BIP122.Dash.chainId, namespace: "BIP122", name: "Dash"),
        .init(chainId: BIP122.DigiByte.chainId, namespace: "BIP122", name: "DigiByte"),
        .init(chainId: BIP122.Ravencoin.chainId, namespace: "BIP122", name: "Ravencoin"),
        .init(chainId: BIP122.Zcash.chainId, namespace: "BIP122", name: "Zcash"),
        .init(chainId: BIP122.Verge.chainId, namespace: "BIP122", name: "Verge"),
        .init(chainId: BIP122.Qtum.chainId, namespace: "BIP122", name: "Qtum"),
        .init(chainId: BIP122.ECash.chainId, namespace: "BIP122", name: "ECash"),
        .init(chainId: TRON.Tron.chainId, namespace: "TRON", name: "Tron"),
        .init(chainId: SOLANA.Solana.chainId, namespace: "SOLANA", name: "Solana"),
        .init(chainId: XRPL.XRPLedger.chainId, namespace: "XRPL", name: "XRPLedger"),
        .init(chainId: STELLAR.Stellar.chainId, namespace: "STELLAR", name: "Stellar"),
        .init(chainId: TEZOS.Tezos.chainId, namespace: "TEZOS", name: "Tezos"),
        .init(chainId: ALGORAND.Algorand.chainId, namespace: "ALGORAND", name: "Algorand"),
        .init(chainId: HEDERA.Hedera.chainId, namespace: "HEDERA", name: "Hedera"),
        .init(chainId: NEO.Neo.chainId, namespace: "NEO", name: "Neo"),
        .init(chainId: FIL.Filecoin.chainId, namespace: "FIL", name: "Filecoin"),
        .init(chainId: MVX.MultiversX.chainId, namespace: "MVX", name: "MultiversX"),
        .init(chainId: STACKS.Stacks.chainId, namespace: "STACKS", name: "Stacks"),
        .init(chainId: IOTA.Iota.chainId, namespace: "IOTA", name: "Iota"),
        .init(chainId: VECHAIN.VeChain.chainId, namespace: "VECHAIN", name: "VeChain"),
        .init(chainId: ARWEAVE.Arweave.chainId, namespace: "ARWEAVE", name: "Arweave"),
        .init(chainId: MINA.Mina.chainId, namespace: "MINA", name: "Mina"),
        .init(chainId: CONFLUX.Conflux.chainId, namespace: "CONFLUX", name: "Conflux"),
        .init(chainId: FLOW.Flow.chainId, namespace: "FLOW", name: "Flow"),
        .init(chainId: COSMOS.CosmosHub.chainId, namespace: "COSMOS", name: "CosmosHub"),
        .init(chainId: COSMOS.THORChain.chainId, namespace: "COSMOS", name: "THORChain"),
        .init(chainId: COSMOS.Terra.chainId, namespace: "COSMOS", name: "Terra"),
        .init(chainId: COSMOS.FetchAI.chainId, namespace: "COSMOS", name: "FetchAI"),
        .init(chainId: POLKADOT.Polkadot.chainId, namespace: "POLKADOT", name: "Polkadot"),
        .init(chainId: POLKADOT.Kusama.chainId, namespace: "POLKADOT", name: "Kusama"),
        .init(chainId: NEAR.Near.chainId, namespace: "NEAR", name: "Near"),
        .init(chainId: CIP34.Cardano.chainId, namespace: "CIP34", name: "Cardano"),
        .init(chainId: ICP.InternetComputer.chainId, namespace: "ICP", name: "InternetComputer"),
        .init(chainId: ONT.Ontology.chainId, namespace: "ONT", name: "Ontology"),
        .init(chainId: ZIL.Zilliqa.chainId, namespace: "ZIL", name: "Zilliqa"),
        .init(chainId: CKB.Nervos.chainId, namespace: "CKB", name: "Nervos"),
        .init(chainId: SIA.Sia.chainId, namespace: "SIA", name: "Sia"),
        .init(chainId: DCR.Decred.chainId, namespace: "DCR", name: "Decred"),
        .init(chainId: POLKADOT.Enjin.chainId, namespace: "POLKADOT", name: "Enjin")
    ]

    /// The namespaces with admitted chains, one generated file each
    static let namespaces = ["EIP155", "BIP122", "TRON", "SOLANA", "XRPL", "STELLAR", "TEZOS", "ALGORAND", "HEDERA", "NEO", "FIL", "MVX", "STACKS", "IOTA", "VECHAIN", "ARWEAVE", "MINA", "CONFLUX", "FLOW", "COSMOS", "POLKADOT", "NEAR", "CIP34", "ICP", "ONT", "ZIL", "CKB", "SIA", "DCR"]

    static let assetsFileName = "Assets+Imported.swift"

    /// The admitted chain CoinGecko calls `platform`, through `AssetRegistry.referenceChainIds`; `nil` for any other
    static func admittedChain(platform: String) -> AdmittedChain? {
        guard let chainId = try? AssetRegistry.chainId(named: platform, by: .coinGecko) else {
            return nil
        }
        return admittedChains.first { $0.chainId == chainId }
    }

    /// One admitted chain's own coin: CoinGecko's id for it, the Swift path of the conformer's constant (the class an
    /// exchange row of the coin names) and the constant
    struct Native: Sendable {
        let coinId: String
        let path: String
        let instance: AssetDeclaration.Instance
    }

    /// The admitted chains' own coins, one for every chain of `BlockChains.knownBlockChains`, each the conformer's home
    /// instance: CoinGecko's id is its asset platforms' `native_coin_id` (verified 2026-10-07) where the chain has a
    /// platform, else the coin's own id as CoinGecko answered it (`fetch-ai`, `enjincoin`, recorded in the chains
    /// work). Optimism's and Base's coin is Ethereum's ether; Theta's EVM chain's is TFUEL, `theta-fuel`, where
    /// CoinGecko's `theta` platform names THETA, `theta-token`, its coin. A coin here is never generated as a token,
    /// whatever home CoinGecko gives it (Fetch.ai's FET and Enjin's ENJ are homed on Ethereum there)
    static let natives: [Native] = [
        .init(coinId: "bitcoin", path: "BIP122.Bitcoin.btc", instance: BIP122.Bitcoin.btc),
        .init(coinId: "ethereum", path: "EIP155.Ethereum.eth", instance: EIP155.Ethereum.eth),
        .init(coinId: "binancecoin", path: "EIP155.BinanceSmartChain.bnb", instance: EIP155.BinanceSmartChain.bnb),
        .init(coinId: "polygon-ecosystem-token", path: "EIP155.Polygon.pol", instance: EIP155.Polygon.pol),
        .init(coinId: "fantom", path: "EIP155.Fantom.ftm", instance: EIP155.Fantom.ftm),
        .init(coinId: "tron", path: "TRON.Tron.trx", instance: TRON.Tron.trx),
        .init(coinId: "avalanche-2", path: "EIP155.Avalanche.avax", instance: EIP155.Avalanche.avax),
        .init(coinId: "ethereum-classic", path: "EIP155.EthereumClassic.etc", instance: EIP155.EthereumClassic.etc),
        .init(coinId: "celo", path: "EIP155.Celo.celo", instance: EIP155.Celo.celo),
        .init(coinId: "theta-fuel", path: "EIP155.Theta.tfuel", instance: EIP155.Theta.tfuel),
        .init(coinId: "coti", path: "EIP155.COTI.coti", instance: EIP155.COTI.coti),
        .init(coinId: "solana", path: "SOLANA.Solana.sol", instance: SOLANA.Solana.sol),
        .init(coinId: "ripple", path: "XRPL.XRPLedger.xrp", instance: XRPL.XRPLedger.xrp),
        .init(coinId: "stellar", path: "STELLAR.Stellar.xlm", instance: STELLAR.Stellar.xlm),
        .init(coinId: "tezos", path: "TEZOS.Tezos.xtz", instance: TEZOS.Tezos.xtz),
        .init(coinId: "algorand", path: "ALGORAND.Algorand.algo", instance: ALGORAND.Algorand.algo),
        .init(coinId: "hedera-hashgraph", path: "HEDERA.Hedera.hbar", instance: HEDERA.Hedera.hbar),
        .init(coinId: "neo", path: "NEO.Neo.neo", instance: NEO.Neo.neo),
        .init(coinId: "filecoin", path: "FIL.Filecoin.fil", instance: FIL.Filecoin.fil),
        .init(coinId: "elrond-erd-2", path: "MVX.MultiversX.egld", instance: MVX.MultiversX.egld),
        .init(coinId: "blockstack", path: "STACKS.Stacks.stx", instance: STACKS.Stacks.stx),
        .init(coinId: "iota", path: "IOTA.Iota.iota", instance: IOTA.Iota.iota),
        .init(coinId: "vechain", path: "VECHAIN.VeChain.vet", instance: VECHAIN.VeChain.vet),
        .init(coinId: "arweave", path: "ARWEAVE.Arweave.ar", instance: ARWEAVE.Arweave.ar),
        .init(coinId: "mina-protocol", path: "MINA.Mina.mina", instance: MINA.Mina.mina),
        .init(coinId: "conflux-token", path: "CONFLUX.Conflux.cfx", instance: CONFLUX.Conflux.cfx),
        .init(coinId: "flow", path: "FLOW.Flow.flow", instance: FLOW.Flow.flow),
        .init(coinId: "litecoin", path: "BIP122.Litecoin.ltc", instance: BIP122.Litecoin.ltc),
        .init(coinId: "dogecoin", path: "BIP122.Dogecoin.doge", instance: BIP122.Dogecoin.doge),
        .init(coinId: "bitcoin-cash", path: "BIP122.BitcoinCash.bch", instance: BIP122.BitcoinCash.bch),
        .init(coinId: "dash", path: "BIP122.Dash.dash", instance: BIP122.Dash.dash),
        .init(coinId: "digibyte", path: "BIP122.DigiByte.dgb", instance: BIP122.DigiByte.dgb),
        .init(coinId: "ravencoin", path: "BIP122.Ravencoin.rvn", instance: BIP122.Ravencoin.rvn),
        .init(coinId: "zcash", path: "BIP122.Zcash.zec", instance: BIP122.Zcash.zec),
        .init(coinId: "verge", path: "BIP122.Verge.xvg", instance: BIP122.Verge.xvg),
        .init(coinId: "qtum", path: "BIP122.Qtum.qtum", instance: BIP122.Qtum.qtum),
        .init(coinId: "ecash", path: "BIP122.ECash.xec", instance: BIP122.ECash.xec),
        .init(coinId: "cosmos", path: "COSMOS.CosmosHub.atom", instance: COSMOS.CosmosHub.atom),
        .init(coinId: "thorchain", path: "COSMOS.THORChain.rune", instance: COSMOS.THORChain.rune),
        .init(coinId: "terra-luna-2", path: "COSMOS.Terra.luna", instance: COSMOS.Terra.luna),
        .init(coinId: "polkadot", path: "POLKADOT.Polkadot.dot", instance: POLKADOT.Polkadot.dot),
        .init(coinId: "kusama", path: "POLKADOT.Kusama.ksm", instance: POLKADOT.Kusama.ksm),
        .init(coinId: "near", path: "NEAR.Near.near", instance: NEAR.Near.near),
        .init(coinId: "cardano", path: "CIP34.Cardano.ada", instance: CIP34.Cardano.ada),
        .init(coinId: "internet-computer", path: "ICP.InternetComputer.icp", instance: ICP.InternetComputer.icp),
        .init(coinId: "ontology", path: "ONT.Ontology.ont", instance: ONT.Ontology.ont),
        .init(coinId: "zilliqa", path: "ZIL.Zilliqa.zil", instance: ZIL.Zilliqa.zil),
        .init(coinId: "nervos-network", path: "CKB.Nervos.ckb", instance: CKB.Nervos.ckb),
        .init(coinId: "siacoin", path: "SIA.Sia.sc", instance: SIA.Sia.sc),
        .init(coinId: "decred", path: "DCR.Decred.dcr", instance: DCR.Decred.dcr),
        .init(coinId: "fetch-ai", path: "COSMOS.FetchAI.fet", instance: COSMOS.FetchAI.fet),
        .init(coinId: "enjincoin", path: "POLKADOT.Enjin.enj", instance: POLKADOT.Enjin.enj)
    ]

    /// ``natives`` by CoinGecko's id: the conformer's constant
    static let nativeCoins: [String: AssetDeclaration.Instance] = Dictionary(
        uniqueKeysWithValues: natives.map { ($0.coinId, $0.instance) }
    )

    /// The members the chain enums already hold by hand, which no generated constant may take: the chains' ids and
    /// coins, and Ethereum's `usdc` and `usdt`, the names `Asset.usdc` and `Asset.usdt` give the generated `usdCoin` and
    /// `tether`; and `Assets.all`, the list this importer writes of every declaration
    static let reservedNames: Set<String> = [
        "namespace", "chainId", "btc", "eth", "bnb", "pol", "ftm", "trx", "avax", "etc", "celo", "tfuel", "coti", "usdc",
        "usdt", "all", "sol", "xrp", "xlm", "xtz", "algo", "hbar", "neo", "gas", "fil", "egld", "stx", "iota", "vet", "vtho", "ar", "mina", "cfx", "flow", "ltc", "doge", "bch", "dash", "dgb", "rvn", "zec", "xvg", "qtum", "xec", "atom", "rune", "luna", "fet", "dot", "ksm", "near", "ada", "icp", "ont", "zil", "ong", "ckb", "sc", "dcr", "enj"
    ]

    /// The coin's Swift name: its CoinGecko id in lowerCamel, `_` before a leading digit
    ///
    /// The id is split at every character that is not an ASCII letter or digit; the first part is kept as given,
    /// each later part has its first letter upper-cased: `usd-coin` is `usdCoin`, `1inch` is `_1inch`.
    static func swiftName(coinId: String) -> String {
        let parts = coinId
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .map(String.init)
        guard let first = parts.first else {
            return ""
        }
        let name = first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return name.first?.isNumber == true ? "_" + name : name
    }

    private static func order(of chain: AdmittedChain, home: AdmittedChain) -> Int {
        chain == home ? -1 : admittedChains.firstIndex(of: chain)!
    }
}

// MARK: The model and the text

extension AssetImporter {
    struct Constant: Hashable, Sendable {
        let name: String
        let coinId: String
        let coinName: String
        let chain: AdmittedChain
        var address: String
        var decimals: Int
        let symbol: String

        var key: String { chain.path + "." + name }
    }

    struct InstanceRef: Hashable, Sendable {
        let chainPath: String
        let name: String
    }

    struct Declaration: Hashable, Sendable {
        let name: String
        let coinId: String
        let tokenName: String
        let symbol: String
        var instances: [InstanceRef]
    }

    static func header(
        _ fileName: String,
        date: String,
        source: String = "CoinGecko",
        handAdditions: String,
        imports: [String] = ["import FOSFoundation", "import Foundation"]
    ) -> String {
        """
        // \(fileName)
        //
        // Copyright © \(date.prefix(4)) FOS Services, LLC. All rights reserved.
        //
        // Generated by Scripts/import-assets.swift from \(source) on \(date); do not edit; hand additions go in \(handAdditions).

        \(imports.joined(separator: "\n"))

        """
    }

    private static func namespaceFile(_ namespace: String, constants: [Constant], date: String) -> String {
        var text = header("\(namespace)+Imported.swift", date: date, handAdditions: "the hand-written \(namespace).swift")
        for chain in admittedChains where chain.namespace == namespace {
            text += "\nextension \(chain.path) {\n"
            let onChain = constants.filter { $0.chain == chain }
            for (index, constant) in onChain.enumerated() {
                if index > 0 { text += "\n" }
                text += """
                    /// \(oneLine(constant.coinName)), CoinGecko's `\(constant.coinId)`, at \(constant.decimals) decimals
                    public static let \(identifier(constant.name)): AssetDeclaration.Instance = try! AssetDeclaration.Instance(
                        instance: AssetInstance(validating: chainId + ":" + "\(literal(constant.address))"),
                        decimals: \(constant.decimals),
                        symbol: AssetSymbol(validating: "\(literal(constant.symbol))")
                    )

                """
            }
            text += "}\n"
        }
        return text
    }

    private static func assetsFile(_ declarations: [Declaration], date: String) -> String {
        var text = header(assetsFileName, date: date, handAdditions: "the hand-written Assets.swift")
        text += "\nextension Assets {\n"
        for (index, declaration) in declarations.enumerated() {
            if index > 0 { text += "\n" }
            let home = declaration.instances[0]
            let instances = declaration.instances
                .map { "            \($0.chainPath).\(identifier($0.name))" }
                .joined(separator: ",\n")
            text += """
                /// \(oneLine(declaration.tokenName)), CoinGecko's `\(declaration.coinId)`: its home on \(home.chainPath), then its other instances
                public static let \(identifier(declaration.name)): AssetDeclaration = try! AssetDeclaration(
                    asset: Asset(validating: \(home.chainPath).\(identifier(home.name)).instance.id),
                    tokenName: "\(literal(declaration.tokenName))",
                    symbol: AssetSymbol(validating: "\(literal(declaration.symbol))"),
                    aggregatorId: "\(literal(declaration.coinId))",
                    instances: [
            \(instances)
                    ]
                )

            """
        }
        // Every declaration above, in the file's order, so the registry's `shared` can hold them all from the start
        let all = declarations.map { "        \(identifier($0.name))" }.joined(separator: ",\n")
        if !declarations.isEmpty { text += "\n" }
        text += """
                /// Every declaration above, in this file's order: what `AssetRegistry.shared` holds from the start
                public static let all: [AssetDeclaration] = [\(declarations.isEmpty ? "]" : "\n" + all + "\n    ]")

            """
        text += "}\n"
        return text
    }

    /// The Swift keywords a coin id could spell, written in backticks
    private static let keywords: Set<String> = [
        "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do",
        "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard", "if", "import",
        "in", "init", "inout", "internal", "is", "let", "nil", "open", "operator", "private", "protocol", "public",
        "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super", "switch", "throw", "throws",
        "true", "try", "typealias", "var", "where", "while"
    ]

    static func identifier(_ name: String) -> String {
        keywords.contains(name) ? "`\(name)`" : name
    }

    static func literal(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func unliteral(_ text: String) -> String {
        text.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "`", with: "'")
    }
}

// MARK: Reading the files as last generated

extension AssetImporter {
    /// The constants and declarations of the files as last generated, read back from their text
    ///
    /// The text is this importer's own, line for line; a line it does not recognize is passed over.
    struct Previous {
        var constants: [Constant] = []
        var declarations: [Declaration] = []

        init(files: [String: String]) {
            for namespace in namespaces {
                if let text = files["\(namespace)+Imported.swift"] {
                    readConstants(text)
                }
            }
            if let text = files[assetsFileName] {
                readDeclarations(text)
            }
        }

        private mutating func readConstants(_ text: String) {
            var chain: AdmittedChain?
            var coinName = "", coinId = "", name = "", address = "", decimals = 0
            for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if let path = between(line, "extension ", " {") {
                    chain = admittedChains.first { $0.path == path }
                } else if let doc = between(line, "/// ", " decimals"),
                          let split = doc.range(of: ", CoinGecko's `") {
                    coinName = String(doc[..<split.lowerBound])
                    coinId = String(doc[split.upperBound...].prefix { $0 != "`" })
                } else if let value = upTo(line, "public static let ", ": AssetDeclaration.Instance = ") {
                    name = value.replacingOccurrences(of: "`", with: "")
                } else if let value = between(line, "instance: AssetInstance(validating: chainId + \":\" + \"", "\"),") {
                    address = unliteral(value)
                } else if let value = between(line, "decimals: ", ","), let number = Int(value) {
                    decimals = number
                } else if let value = between(line, "symbol: AssetSymbol(validating: \"", "\")"), let chain {
                    constants.append(Constant(
                        name: name, coinId: coinId, coinName: coinName, chain: chain,
                        address: address, decimals: decimals, symbol: unliteral(value)
                    ))
                }
            }
        }

        private mutating func readDeclarations(_ text: String) {
            var coinId = "", name = "", tokenName = "", symbol = ""
            var instances: [InstanceRef] = []
            var inInstances = false
            for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if let value = upTo(line, "public static let ", ": AssetDeclaration = ") {
                    name = value.replacingOccurrences(of: "`", with: "")
                    instances = []
                } else if let value = between(line, "tokenName: \"", "\",") {
                    tokenName = unliteral(value)
                } else if let value = between(line, "symbol: AssetSymbol(validating: \"", "\"),") {
                    symbol = unliteral(value)
                } else if let value = between(line, "aggregatorId: \"", "\",") {
                    coinId = unliteral(value)
                } else if line == "instances: [" {
                    inInstances = true
                } else if inInstances, line == "]" {
                    inInstances = false
                    declarations.append(Declaration(
                        name: name, coinId: coinId, tokenName: tokenName, symbol: symbol, instances: instances
                    ))
                } else if inInstances {
                    let parts = line.replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: "`", with: "")
                        .split(separator: ".")
                    if parts.count == 3 {
                        instances.append(InstanceRef(chainPath: parts[0] + "." + parts[1], name: String(parts[2])))
                    }
                }
            }
        }

        private func upTo(_ line: String, _ prefix: String, _ marker: String) -> String? {
            guard line.hasPrefix(prefix), let end = line.range(of: marker) else {
                return nil
            }
            return String(line[line.index(line.startIndex, offsetBy: prefix.count)..<end.lowerBound])
        }

        private func between(_ line: String, _ prefix: String, _ suffix: String) -> String? {
            guard line.hasPrefix(prefix), line.hasSuffix(suffix), line.count >= prefix.count + suffix.count else {
                return nil
            }
            return String(line.dropFirst(prefix.count).dropLast(suffix.count))
        }
    }
}
