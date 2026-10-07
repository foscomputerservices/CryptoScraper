// D21 — The bridge from TokenInfo to a declared instance.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.1: "An on-chain instance from what the reference
// loaded into its chain, with the decimals its scanner states" — `init<Info: TokenInfo>(_ info: Info, decimals: Int)
// throws`. And "Three fields are your `TokenInfo`'s, by its names."

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D21 TokenInfo bridge")
struct D21_TokenInfoBridgeTests {
    private let usdc = EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")

    // invented: SimpleTokenInfo(contract:tokenName:symbol:aggregatorId:) — the 2023 type is named in the design; its initializer is not quoted
    private func info() -> SimpleTokenInfo<EthereumContract> {
        SimpleTokenInfo(contract: usdc, tokenName: "USD Coin", symbol: "USDC", aggregatorId: "usd-coin")
    }

    // "An on-chain instance from what the reference loaded into its chain" — the instance is the contract's
    @Test func instanceIsTheContracts() throws {
        let instance = try AssetDeclaration.Instance(info(), decimals: 6)
        #expect(instance.instance == AssetInstance(usdc))
        #expect(instance.instance == EIP155.Ethereum.usdc.instance)
    }

    // "with the decimals its scanner states"
    @Test func decimalsAreTheOnesGiven() throws {
        #expect(try AssetDeclaration.Instance(info(), decimals: 6).decimals == 6)
    }

    // "Your `TokenInfo.symbol` is an asset's default." (§ 1.6) — the instance's symbol is the token info's
    @Test func symbolIsTheTokenInfos() throws {
        #expect(try AssetDeclaration.Instance(info(), decimals: 6).symbol.text == "USDC")
    }

    // "Throws ``AssetError/decimalsOutOfRange(_:)`` outside 0 through 30" — through the bridge as well
    @Test func decimalsOutOfRangeThrowThroughTheBridge() {
        #expect(throws: AssetError.decimalsOutOfRange(31)) { try AssetDeclaration.Instance(info(), decimals: 31) }
    }

    // "the generated constants" agree with the bridge: the importer and the bridge state one instance
    @Test func bridgeAgreesWithTheGeneratedConstant() throws {
        #expect(try AssetDeclaration.Instance(info(), decimals: 6) == EIP155.Ethereum.usdc)
    }
}
