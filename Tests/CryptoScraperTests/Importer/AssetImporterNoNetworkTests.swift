// AssetImporterNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import Foundation
import Testing

/// Design § 2.7, the importer: CoinGecko's recorded answers generate the `+Imported.swift` files and a report, only
/// on the library's admitted chains, with names from CoinGecko's ids; regeneration adds and renames and never changes
/// an address or a decimals. No network.
@Suite struct AssetImporterNoNetworkTests {
    // MARK: The admitted chains

    @Test(arguments: [
        ("ethereum", EIP155.Ethereum.chainId, "EIP155.Ethereum"),
        ("binance-smart-chain", EIP155.BinanceSmartChain.chainId, "EIP155.BinanceSmartChain"),
        ("polygon-pos", EIP155.Polygon.chainId, "EIP155.Polygon"),
        ("optimistic-ethereum", EIP155.Optimism.chainId, "EIP155.Optimism"),
        ("fantom", EIP155.Fantom.chainId, "EIP155.Fantom"),
        ("tron", TRON.Tron.chainId, "TRON.Tron")
    ])
    func eachCoinGeckoPlatformOfTheTableLandsOnItsChain(platform: String, chainId: String, path: String) throws {
        let chain = try #require(AssetImporter.admittedChain(platform: platform))
        #expect(chain.chainId == chainId)
        #expect(chain.path == path)
    }

    @Test(arguments: ["aptos", "arbitrum-one", "Ethereum", "bitcoin", ""])
    func aPlatformTheTableLacksIsNoAdmittedChain(platform: String) {
        #expect(AssetImporter.admittedChain(platform: platform) == nil)
    }

    @Test func theAdmittedChainsAreCryptoScrapersChains() {
        #expect(AssetImporter.admittedChains.count == 54)
        #expect(Set(AssetImporter.admittedChains.map(\.chainId)) == Set(BlockChains.knownBlockChains.map(\.id)))
        #expect(AssetImporter.admittedChains.contains { $0.path == "BIP122.Bitcoin" })
    }

    // MARK: The generated text

    @Test(arguments: CoinGeckoRecorded.expectedFileNames)
    func theRecordedAnswersGenerateTheExpectedFileByteForByte(fileName: String) throws {
        let (files, _) = try AssetImporter.generate(
            coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date,
            chainDecimals: CoinGeckoRecorded.chainDecimals()
        )

        #expect(Set(files.keys) == Set(CoinGeckoRecorded.expectedFileNames))
        #expect(files[fileName] == CoinGeckoRecorded.expected(fileName))
    }

    // A namespace file's hand additions live in the namespace's hand-written file, `Assets`' in Assets.swift; no
    // overrides file exists in CryptoAsset
    @Test func eachFilesHeaderNamesWhereItsHandAdditionsGo() throws {
        let (files, _) = try AssetImporter.generate(coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date)

        for namespace in AssetImporter.namespaces {
            let file = try #require(files["\(namespace)+Imported.swift"])
            #expect(file.contains("hand additions go in the hand-written \(namespace).swift."), "\(namespace)")
            #expect(!file.contains("overrides"), "\(namespace)")
        }
        let assets = try #require(files[AssetImporter.assetsFileName])
        #expect(assets.contains("hand additions go in the hand-written Assets.swift."))
    }

    @Test func theRecordedAnswersReportWhatWasLeftOut() throws {
        let (_, report) = try AssetImporter.generate(
            coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date,
            chainDecimals: CoinGeckoRecorded.chainDecimals()
        )

        #expect(report.counts == [
            "native": 3,
            // usd-coin's 36 platforms less its 13 on admitted chains; tether's 11 less 6, and less Tezos, admitted
            // with no decimals; pepe's 4 less 3
            "chainNotAdmitted": 23 + 4 + 1,
            "noDecimals": 1,
            // USDC on Algorand: CoinGecko's 5 against the chain's 6
            "decimalsDisagree": 1
        ])
    }

    // MARK: The chain's decimals (design § 4.1: a token's decimals come from its chain's scanner, the oracle)

    @Test func theChainsDecimalsWinOverCoinGeckosAndTheDisagreementIsReported() throws {
        let (files, report) = try AssetImporter.generate(
            coins: [CoinGeckoRecorded.coin("usd-coin")], date: CoinGeckoRecorded.date,
            chainDecimals: CoinGeckoRecorded.chainDecimals()
        )

        let usdc = try #require(AssetImporter.Previous(files: files).constants.first { $0.key == "ALGORAND.Algorand.usdCoin" })
        #expect(usdc.decimals == 6)
        #expect(report.findings.filter { $0.kind == "decimalsDisagree" } == [
            .decimalsDisagree(coinId: "usd-coin", platform: "algorand", kept: 6, refused: 5)
        ])
    }

    /// Etherscan's recorded USDC transfers state 6, as CoinGecko does: no finding
    @Test func aChainsDecimalsThatAgreeAreNoFinding() throws {
        let decimals = try CoinGeckoRecorded.chainDecimals()
        let (files, report) = try AssetImporter.generate(
            coins: [CoinGeckoRecorded.coin("usd-coin")], date: CoinGeckoRecorded.date,
            chainDecimals: [EIP155.Ethereum.chainId: try #require(decimals[EIP155.Ethereum.chainId])]
        )

        let usdc = try #require(AssetImporter.Previous(files: files).constants.first { $0.key == "EIP155.Ethereum.usdCoin" })
        #expect(usdc.decimals == 6)
        #expect(!report.findings.contains { $0.kind == "decimalsDisagree" })
    }

    @Test func aChainsDecimalsStandWhereCoinGeckoStatesNone() throws {
        let (files, report) = AssetImporter.generate(
            coins: [.made(id: "fred", on: ["ethereum": (nil, "0x42")])], date: CoinGeckoRecorded.date,
            chainDecimals: [EIP155.Ethereum.chainId: ["0x42": 18]]
        )

        let fred = try #require(AssetImporter.Previous(files: files).constants.first { $0.key == "EIP155.Ethereum.fred" })
        #expect(fred.decimals == 18)
        #expect(report.findings.isEmpty)
    }

    @Test func aChainsDecimalsOutsideTheRangeAreNoDecimals() {
        let (_, report) = AssetImporter.generate(
            coins: [.made(id: "fred", on: ["ethereum": (18, "0x42")])], date: CoinGeckoRecorded.date,
            chainDecimals: [EIP155.Ethereum.chainId: ["0x42": 31]]
        )

        #expect(report.findings.contains(.noDecimals(coinId: "fred", platform: "ethereum")))
    }

    /// Regeneration never changes a decimals (design § 2.7): a constant generated before at CoinGecko's figure keeps
    /// it, and both the refusal and the disagreement are reported
    @Test func aChainsDecimalsNeverChangeAConstantGeneratedBefore() throws {
        let usdc = try CoinGeckoRecorded.coin("usd-coin")
        let (first, _) = AssetImporter.generate(coins: [usdc], date: CoinGeckoRecorded.date)
        let (second, report) = try AssetImporter.generate(
            coins: [usdc], date: CoinGeckoRecorded.date, previous: first,
            chainDecimals: CoinGeckoRecorded.chainDecimals()
        )

        #expect(second == first)
        #expect(report.findings.contains(.decimalsDisagree(coinId: "usd-coin", platform: "algorand", kept: 6, refused: 5)))
        #expect(report.findings.contains(
            .decimalsChanged(name: "usdCoin", chainId: ALGORAND.Algorand.chainId, kept: 5, refused: 6)
        ))
    }

    @Test(arguments: [
        ("usd-coin", EIP155.Ethereum.usdc),
        ("tether", EIP155.Ethereum.usdt)
    ])
    func aWellKnownTokensGeneratedInstanceIsTheHandWrittenOne(
        coinId: String,
        handWritten: AssetDeclaration.Instance
    ) throws {
        let (files, _) = try AssetImporter.generate(coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date)
        let generated = AssetImporter.Previous(files: files)

        let constant = try #require(generated.constants.first { $0.coinId == coinId && $0.chain.path == "EIP155.Ethereum" })
        #expect(constant.chain.chainId + ":" + constant.address == handWritten.instance.id)
        #expect(constant.decimals == handWritten.decimals)
        #expect(constant.symbol == handWritten.symbol.text)
        let declaration = try #require(generated.declarations.first { $0.coinId == coinId })
        #expect(declaration.instances.first == .init(chainPath: "EIP155.Ethereum", name: constant.name))
    }

    @Test(arguments: [
        ("bitcoin", BIP122.Bitcoin.btc),
        ("ethereum", EIP155.Ethereum.eth)
    ])
    func aWellKnownNativeIsTheConformersAndNeverGenerated(
        coinId: String,
        handWritten: AssetDeclaration.Instance
    ) throws {
        let (files, report) = try AssetImporter.generate(
            coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date
        )
        let generated = AssetImporter.Previous(files: files)

        #expect(report.findings.contains(.native(coinId: coinId, instance: handWritten.instance.id)))
        #expect(!generated.constants.contains { $0.coinId == coinId })
        #expect(!generated.declarations.contains { $0.coinId == coinId })
    }

    @Test func solanasCoinIsTheConformersAndIsNeverGenerated() throws {
        let (files, report) = try AssetImporter.generate(
            coins: [CoinGeckoRecorded.coin("solana")], date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.native(coinId: "solana", instance: SOLANA.Solana.sol.instance.id)])
        #expect(report.counts == ["native": 1])
        #expect(AssetImporter.Previous(files: files).declarations.isEmpty)
    }

    // Every admitted chain's own coin is a native of the importer's one table, so no admitted chain's coin is ever
    // generated as a token: the conformer's main contract is an instance of a native's asset (Optimism's and Base's
    // ether is Ethereum's, Theta's TFUEL its own)
    @Test func everyAdmittedChainsOwnCoinIsANative() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let natives = try Set(AssetImporter.nativeCoins.values.map { try registry.asset(of: $0.instance) })
        for chain in BlockChains.knownBlockChains {
            let main = Self.mainInstance(of: chain)
            #expect(try natives.contains(registry.asset(of: main)), "\(main.id) is no native's")
        }
    }

    // The exchange tables' classes and the natives are one table: each native's Swift path is on its own chain
    @Test func theExchangeClassesAreTheNativesPaths() throws {
        #expect(Set(AssetImporter.nativePaths.keys) == Set(AssetImporter.nativeCoins.keys))
        for (coinId, native) in AssetImporter.nativeCoins {
            let chain = try #require(AssetImporter.admittedChains.first { $0.chainId == native.instance.chainId })
            #expect(AssetImporter.nativePaths[coinId]?.hasPrefix(chain.path + ".") == true, "\(coinId)")
        }
    }

    // CoinGecko gives Fetch.ai's and Enjin's coins an Ethereum home; each is its own chain's coin, never a token
    @Test(arguments: [
        ("fetch-ai", COSMOS.FetchAI.fet),
        ("enjincoin", POLKADOT.Enjin.enj)
    ])
    func aNativeCoinWithAPlatformIsTheConformersAndNeverGenerated(
        coinId: String,
        native: AssetDeclaration.Instance
    ) {
        let (files, report) = AssetImporter.generate(
            coins: [.made(id: coinId, home: "ethereum")], date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.native(coinId: coinId, instance: native.instance.id)])
        #expect(AssetImporter.Previous(files: files).constants.isEmpty)
    }

    private static func mainInstance<Chain: CryptoChain>(of chain: Chain) -> AssetInstance {
        AssetInstance(chain.mainContract)
    }

    @Test func aTokenWhoseHomeIsOnAChainNotAdmittedIsLeftOutAndCounted() {
        let (_, report) = AssetImporter.generate(
            coins: [.made(
                id: "fred-on-arbitrum", home: "arbitrum-one",
                on: ["arbitrum-one": (18, "0x42"), "ethereum": (18, "0x43")]
            )],
            date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.homeChainNotAdmitted(coinId: "fred-on-arbitrum", platform: "arbitrum-one")])
    }

    @Test func pepeOnEthereumGenerates() throws {
        let (files, report) = try AssetImporter.generate(
            coins: [CoinGeckoRecorded.coin("pepe")], date: CoinGeckoRecorded.date
        )
        let generated = AssetImporter.Previous(files: files)

        let pepe = try #require(generated.constants.first { $0.key == "EIP155.Ethereum.pepe" })
        #expect(pepe.address == "0x6982508145454ce325ddbe47a25d4ec3d2311933")
        #expect(pepe.decimals == 18)
        #expect(pepe.symbol == "PEPE")
        #expect(generated.constants.map(\.key) == [
            "EIP155.Ethereum.pepe", "EIP155.BinanceSmartChain.pepe", "EIP155.Avalanche.pepe"
        ])
        #expect(generated.declarations.map(\.name) == ["pepe"])
        #expect(generated.declarations.first?.instances.map(\.chainPath) == [
            "EIP155.Ethereum", "EIP155.BinanceSmartChain", "EIP155.Avalanche"
        ])
        #expect(report.counts == ["chainNotAdmitted": 1])
    }

    @Test func aCoinWithNoInstanceOnItsOwnChainIsLeftOutAndCounted() {
        let (files, report) = AssetImporter.generate(
            coins: [.made(id: "fred", on: ["ethereum": (nil, "0x42"), "polygon-pos": (18, "0x43")])],
            date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.noDecimals(coinId: "fred", platform: "ethereum"), .noInstance(coinId: "fred")])
        #expect(AssetImporter.Previous(files: files).constants.isEmpty)
    }

    @Test func aMalformedSymbolLeavesTheCoinOut() {
        let (_, report) = AssetImporter.generate(
            coins: [.made(id: "figure-heloc", symbol: "figr_heloc")], date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.malformedSymbol(coinId: "figure-heloc", symbol: "figr_heloc")])
    }

    // MARK: Names

    @Test(arguments: [
        ("usd-coin", "usdCoin"),
        ("tether", "tether"),
        ("1inch", "_1inch"),
        ("0x-protocol", "_0xProtocol"),
        ("wrapped-steth", "wrappedSteth"),
        ("bridged-usdc-polygon-pos-bridge", "bridgedUsdcPolygonPosBridge"),
        ("a.b_c", "aBC")
    ])
    func aNameIsTheCoinGeckoIdInLowerCamelNeverTheSymbol(coinId: String, name: String) {
        #expect(AssetImporter.swiftName(coinId: coinId) == name)
    }

    @Test func aDigitLeadingIdGeneratesAnUnderscoredConstant() throws {
        let (files, _) = AssetImporter.generate(
            coins: [.made(id: "1inch", symbol: "1inch")], date: CoinGeckoRecorded.date
        )

        let text = try #require(files["EIP155+Imported.swift"])
        #expect(text.contains("    public static let _1inch: AssetDeclaration.Instance = try! AssetDeclaration.Instance("))
        #expect(files["Assets+Imported.swift"]?.contains("    public static let _1inch: AssetDeclaration = ") == true)
    }

    @Test func aCollisionAfterConversionLeavesTheLaterCoinOut() {
        let (files, report) = AssetImporter.generate(
            coins: [.made(id: "usd-coin", symbol: "usdc"), .made(id: "usd_coin", symbol: "usdx")],
            date: CoinGeckoRecorded.date
        )

        #expect(report.findings == [.nameCollision(coinId: "usd_coin", name: "usdCoin", with: "usd-coin")])
        #expect(AssetImporter.Previous(files: files).declarations.map(\.coinId) == ["usd-coin"])
    }

    @Test func aNameAChainEnumHoldsByHandIsACollision() {
        let (_, report) = AssetImporter.generate(coins: [.made(id: "chain-id")], date: CoinGeckoRecorded.date)

        #expect(report.findings == [.nameCollision(coinId: "chain-id", name: "chainId", with: "the hand-written chainId")])
    }

    // Step 8c: `Assets.all` lists every generated declaration, so no coin may take its name.
    @Test func aNameTheGeneratedListHoldsIsACollision() {
        let (_, report) = AssetImporter.generate(coins: [.made(id: "all")], date: CoinGeckoRecorded.date)

        #expect(report.findings == [.nameCollision(coinId: "all", name: "all", with: "Assets.all")])
    }

    // MARK: Regeneration

    @Test func regeneratingFromTheSameAnswerChangesNothing() throws {
        let coins = try CoinGeckoRecorded.sixCoins()
        let (first, _) = AssetImporter.generate(coins: coins, date: CoinGeckoRecorded.date)
        let (second, report) = AssetImporter.generate(coins: coins, date: CoinGeckoRecorded.date, previous: first)

        #expect(second == first)
        #expect(!report.findings.contains { $0.kind == "addressChanged" || $0.kind == "decimalsChanged" })
    }

    @Test func aChangedDecimalsIsRefusedAndReported() throws {
        let usdc = try CoinGeckoRecorded.coin("usd-coin")
        let (first, _) = AssetImporter.generate(coins: [usdc], date: CoinGeckoRecorded.date)
        let (second, report) = AssetImporter.generate(
            coins: [usdc.with(detail: "ethereum", decimals: 8)], date: CoinGeckoRecorded.date, previous: first
        )

        #expect(second == first)
        #expect(report.findings.contains(
            .decimalsChanged(name: "usdCoin", chainId: EIP155.Ethereum.chainId, kept: 6, refused: 8)
        ))
    }

    @Test func aChangedAddressIsRefusedAndReported() throws {
        let usdc = try CoinGeckoRecorded.coin("usd-coin")
        let (first, _) = AssetImporter.generate(coins: [usdc], date: CoinGeckoRecorded.date)
        let (second, report) = AssetImporter.generate(
            coins: [usdc.with(detail: "polygon-pos", address: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174")],
            date: CoinGeckoRecorded.date, previous: first
        )

        #expect(second == first)
        #expect(report.findings.contains(.addressChanged(
            name: "usdCoin", chainId: EIP155.Polygon.chainId,
            kept: "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
            refused: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
        )))
    }

    @Test func aChangedSymbolRegeneratesTheSymbolOnly() throws {
        let usdc = try CoinGeckoRecorded.coin("usd-coin")
        let (first, _) = AssetImporter.generate(coins: [usdc], date: CoinGeckoRecorded.date)
        let (second, report) = AssetImporter.generate(
            coins: [usdc.with(symbol: "usdc.e")], date: CoinGeckoRecorded.date, previous: first
        )

        let renamed = first.mapValues {
            $0.replacingOccurrences(of: "AssetSymbol(validating: \"USDC\")", with: "AssetSymbol(validating: \"USDC.E\")")
        }
        #expect(second == renamed)
        #expect(second != first)
        #expect(!report.findings.contains { $0.kind == "addressChanged" || $0.kind == "decimalsChanged" })
    }

    @Test func aNewCoinAddsAfterTheConstantsGeneratedBefore() throws {
        let tether = try CoinGeckoRecorded.coin("tether")
        let pepe = try CoinGeckoRecorded.coin("pepe")
        let (first, _) = AssetImporter.generate(coins: [tether], date: CoinGeckoRecorded.date)
        let (second, _) = AssetImporter.generate(coins: [pepe, tether], date: CoinGeckoRecorded.date, previous: first)

        let generated = AssetImporter.Previous(files: second)
        #expect(generated.declarations.map(\.coinId) == ["tether", "pepe"])
        #expect(generated.constants.map(\.key) == [
            "EIP155.Ethereum.tether", "EIP155.Ethereum.pepe", "EIP155.BinanceSmartChain.pepe", "EIP155.Avalanche.tether",
            "EIP155.Avalanche.pepe", "EIP155.Celo.tether", "TRON.Tron.tether", "SOLANA.Solana.tether",
            "NEAR.Near.tether"
        ])
        #expect(second["TRON+Imported.swift"] == first["TRON+Imported.swift"])
    }

    @Test func aConstantTheAnswerNoLongerListsIsCarried() throws {
        let (first, _) = try AssetImporter.generate(coins: CoinGeckoRecorded.sixCoins(), date: CoinGeckoRecorded.date)
        let (second, report) = AssetImporter.generate(coins: [], date: CoinGeckoRecorded.date, previous: first)

        #expect(second == first)
        #expect(report.findings.isEmpty)
    }
}
