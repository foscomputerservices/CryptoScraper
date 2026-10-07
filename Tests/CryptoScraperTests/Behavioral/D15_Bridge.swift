// D15 — The bridge, from the owner's protocols to the values.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.5: "`init(_ contract: some CryptoContract)`,
// `init(_ fiat: some FiatCurrency)`" and "One direction of authority. The bridge reads `contract.id`. If your `id`
// changes, the instance follows." and "The contract an instance names, on a chain or an exchange this library knows;
// `nil` for a fiat". And § 1.7: "A test asserts `AssetInstance(EthereumChain.default.mainContract).id == Asset.eth.id`,
// and the same for the others." And § 1.4: "A bridged fiat's id is `iso4217:USD`."

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D15 The bridge")
struct D15_BridgeTests {
    // "`AssetInstance(EthereumChain.default.mainContract).id == Asset.eth.id`"
    @Test func ethereumsCoinIsAssetEth() throws {
        let eth = try #require(EthereumChain.default.mainContract)
        #expect(AssetInstance(eth).id == Asset.eth.id)
    }

    // "and the same for the others" — Bitcoin
    @Test func bitcoinsCoinIsAssetBTC() throws {
        let btc = try #require(BitcoinChain.default.mainContract)
        #expect(AssetInstance(btc).id == Asset.btc.id)
    }

    // "and the same for the others" — USDC and USDT on Ethereum
    @Test func ethereumTokensAreTheirAssets() {
        #expect(AssetInstance(EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")).id == Asset.usdc.id)
        #expect(AssetInstance(EthereumContract(address: "0xdac17f958d2ee523a2206206994597c13d831ec7")).id == Asset.usdt.id)
    }

    // "A bridged fiat's id is `iso4217:USD`."
    @Test func theDollarBridgesToISO4217() {
        // invented: USD() — the 2023 fiat's initializer is not quoted in the design
        #expect(AssetInstance(USD()).id == "iso4217:USD")
        #expect(AssetInstance(USD()).id == Asset.usd.id)
    }

    // "The bridge reads `contract.id`."
    @Test func bridgeReadsTheContractsId() {
        let usdc = EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(AssetInstance(usdc).id == usdc.id)
    }

    // "The bridge builds through `init(address:)`, which normalizes." (§ 7.2) — a shouted address bridges to the same instance
    @Test func bridgeOfANormalizedContract() {
        let shouted = EthereumContract(address: "0x" + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48".uppercased())
        #expect(AssetInstance(shouted) == EIP155.Ethereum.usdc.instance)
    }

    // "`nil` for a fiat"
    @Test func contractOfAFiatIsNil() {
        #expect(BlockChains.contract(of: ISO4217.usd.instance) == nil)
    }

    // "The contract an instance names, on a chain ... this library knows"
    @Test func contractOfEthereumsCoin() throws {
        let contract = try #require(BlockChains.contract(of: EIP155.Ethereum.eth.instance))
        #expect(contract.id == EIP155.Ethereum.eth.instance.id)
        #expect((contract as? EthereumContract)?.isChainToken == true)
    }

    // "The contract an instance names" — a token round-trips instance → contract → instance
    @Test func contractOfATokenRoundTrips() throws {
        let contract = try #require(BlockChains.contract(of: EIP155.Ethereum.usdc.instance))
        #expect(AssetInstance(contract) == EIP155.Ethereum.usdc.instance)
    }

    // "on a chain or an exchange this library knows" — a chain it does not know gives nil
    @Test func contractOnAnUnknownChainIsNil() {
        #expect(BlockChains.contract(of: .stub()) == nil)
    }
}
