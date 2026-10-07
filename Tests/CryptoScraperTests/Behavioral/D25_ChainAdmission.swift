// D25 — The chains, each a Swift type, admitted by its tests and its oracles (the six items, for the seven chains).
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.5: "1. The conformer, in your pattern, with its
// CAIP-2 `id` ..., `mainContract`, its token table, `contract(for:)` with its own address normalization, and a `Units`
// ladder whose base unit is exponent 0. 2. Its scanner ... 3. Its instances in the statement ... 4. Its rows in the
// reference-name table ... 5. Its place in `BlockChains.knownBlockChains`. 6. Its tests (§ 6), from recorded answers".
// And § 6's per-chain bullets; § 2.2: "So the statement states each decimals, and a test proves it against the ladder
// where the ladder reads true. The ladder is not touched." And the owner's ruling of 2026-10-07: a chain that names no
// sub-unit counts in its base unit at exponent 0.

import CryptoAsset
import CryptoScraper
import FOSFoundation
import Foundation
import Testing

@Suite("D25 Chain admission")
struct D25_ChainAdmissionTests {
    private func registry() throws -> AssetRegistry {
        try AssetRegistry(AssetRegistry.libraryDeclarations)
    }

    // "Its main contract: `isChainToken`, its placeholder address, and `AssetInstance(mainContract).id`." — Ethereum
    @Test func ethereumMainContract() throws {
        let eth = try #require(EthereumChain.default.mainContract)
        #expect(eth.isChainToken)
        #expect(eth.address == "eth")
        #expect(AssetInstance(eth).id == EIP155.Ethereum.eth.instance.id)
    }

    // the same — Bitcoin ("`bip122:…:btc`")
    @Test func bitcoinMainContract() throws {
        let btc = try #require(BitcoinChain.default.mainContract)
        #expect(btc.isChainToken)
        #expect(btc.address == "btc")
        #expect(AssetInstance(btc).id == BIP122.Bitcoin.btc.instance.id)
    }

    // the same — every one of the seven is a chain token
    @Test func everyMainContractIsTheChainToken() {
        // invented: BNBChain, PolygonChain, OptimismChain, FantomChain — the 2023 class names are not quoted in the design
        #expect(BNBChain.default.mainContract?.isChainToken == true)
        #expect(PolygonChain.default.mainContract?.isChainToken == true)
        #expect(OptimismChain.default.mainContract?.isChainToken == true)
        #expect(FantomChain.default.mainContract?.isChainToken == true)
        #expect(TronChain.default.mainContract?.isChainToken == true)
    }

    // "Its ladder against the statement: base 10^0, whole 10^(declared decimals)." — Bitcoin, where the ladder reads true
    @Test func bitcoinLadderAgreesWithTheStatement() throws {
        // invented: BitcoinContract.Units.satoshi/.btc and their `exponent` — "`.btc` 10^8, `.satoshi` 10^0"; the ladder's member names beyond the cases are not quoted
        #expect(BitcoinContract.Units.satoshi.exponent == 0)
        #expect(BitcoinContract.Units.btc.exponent == (try registry().decimals(of: BIP122.Bitcoin.btc.instance)))
    }

    // "Ether reads true: `.ether` is 10^18"
    @Test func etherLadderAgreesWithTheStatement() throws {
        // invented: EthereumContract.Units.ether and its `exponent` — as above
        #expect(EthereumContract.Units.ether.exponent == (try registry().decimals(of: EIP155.Ethereum.eth.instance)))
    }

    // "The seven existing chains get it too, so the off-by-one for wei and sun is stated by a test." / "The ladder is not touched."
    @Test func weiAndSunOffByOneIsStated() {
        // invented: EthereumContract.Units.wei and TronContract.Units.sun with `exponent` — "Wei and sun read 1, not 0"
        #expect(EthereumContract.Units.wei.exponent == 1)
        #expect(TronContract.Units.sun.exponent == 1)
    }

    // owner, 2026-10-07: a chain that names no sub-unit counts in its base unit at exponent 0 — the statement says 0 for wei
    @Test func statementCountsWeiAtExponentZero() throws {
        let registry = try registry()
        #expect(try registry.declaration(of: .eth).unit(named: "wei")?.exponent == 0)
        let oneWei = Amount(baseUnits: 1, of: EIP155.Ethereum.eth.instance)
        let wei = try #require(try registry.declaration(of: .eth).unit(named: "wei"))
        #expect(try oneWei.count(in: wei, in: registry).count == 1)
    }

    // "Its addresses: normalization through `contract(for:)` and a `Codable` round trip."
    @Test func ethereumAddressNormalizesThroughContractFor() throws {
        let shouted = "0x" + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48".uppercased()
        let contract = try EthereumChain.default.contract(for: shouted)
        #expect(contract.address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
    }

    // "and a `Codable` round trip"
    @Test func ethereumContractRoundTrips() throws {
        let usdc = EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        let back: EthereumContract = try usdc.toJSON().fromJSON()
        #expect(back == usdc)
    }

    // "A token's decimals from its scanner, the oracle: Etherscan's `divisor` for USDC is 6."
    @Test(.disabled("Classified 2026-10-07: no recording of Etherscan's token info for USDC (the one recorded is its refusal of a free key, tokeninfo-ethereum-usdc-free-key-refused.json), and the 2023 Etherscan takes no session; see the identity ledger")) func etherscanDivisorForUSDCIsSix() async throws {
        // invented: Etherscan(session:) with RecordedEtherscan.session(answering:) and `tokenDecimals(for:)` — "Etherscan's token
        // info decodes a `divisor` and hands it up nowhere"; the member that hands it up is not declared
        let scanner = Etherscan(session: RecordedEtherscan.session(answering: "tokeninfo-usdc"))
        let decimals = try await scanner.tokenDecimals(for: EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"))
        #expect(decimals == EIP155.Ethereum.usdc.decimals)
    }

    // "The aggregator's rows land on it through the § 2.4 table." — each source name lands on its conformer's id
    @Test func aggregatorRowsLandOnTheConformers() throws {
        #expect(try AssetRegistry.chainId(named: "ethereum", by: .coinGecko) == EthereumChain.default.id)
        #expect(try AssetRegistry.chainId(named: "Ethereum", by: .coinMarketCap) == EthereumChain.default.id)
        #expect(try AssetRegistry.chainId(named: "tron", by: .coinGecko) == TronChain.default.id)
        // invented: BNBChain, PolygonChain, OptimismChain, FantomChain — as above
        #expect(try AssetRegistry.chainId(named: "binance-smart-chain", by: .coinGecko) == BNBChain.default.id)
        #expect(try AssetRegistry.chainId(named: "polygon-pos", by: .coinGecko) == PolygonChain.default.id)
        #expect(try AssetRegistry.chainId(named: "optimistic-ethereum", by: .coinGecko) == OptimismChain.default.id)
        #expect(try AssetRegistry.chainId(named: "fantom", by: .coinGecko) == FantomChain.default.id)
    }

    // "Its place in `BlockChains.knownBlockChains`." — read through the public door: contract(of:) answers for its coin
    @Test func everyChainIsKnownToBlockChains() throws {
        for coin in [EIP155.Ethereum.eth.instance, BIP122.Bitcoin.btc.instance] {
            #expect(BlockChains.contract(of: coin) != nil)
        }
        for chain in [BNBChain.default.mainContract.map(AssetInstance.init), PolygonChain.default.mainContract.map(AssetInstance.init),
                      OptimismChain.default.mainContract.map(AssetInstance.init), FantomChain.default.mainContract.map(AssetInstance.init),
                      TronChain.default.mainContract.map(AssetInstance.init)] {
            let instance = try #require(chain)
            #expect(BlockChains.contract(of: instance) != nil)
        }
    }

    // "Its instances in the statement: its native coin's" — Ethereum's and Bitcoin's coins are declared
    @Test func nativeCoinsAreDeclared() throws {
        let registry = try registry()
        #expect(try registry.asset(of: EIP155.Ethereum.eth.instance) == .eth)
        #expect(try registry.asset(of: BIP122.Bitcoin.btc.instance) == .btc)
    }

    // "Your protocol's `scanner` becomes non-optional" — "a test reads `EthereumChain.default.scanner.userReadableName` with no unwrap"
    @Test func scannerIsReadWithNoUnwrap() {
        let name: String = EthereumChain.default.scanner.userReadableName
        #expect(!name.isEmpty)
    }
}
