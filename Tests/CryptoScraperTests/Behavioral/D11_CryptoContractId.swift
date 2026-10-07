// D11 — The owner's 2023 types, adopted as they are.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.1: "`var id: String { chain.id + \":\" + address }`"
// and "A token is its contract, the address lower-cased by your initializer" and "A chain's coin is
// `EthereumChain.default.mainContract`, address `\"eth\"`". And § 1.2: "`ZeroAmountChain` keeps the reflected default.
// It is never bridged, so its id is never stored." And § 1.5: "Two instances are equal when their ids are, as your `==`
// compares chain and address".

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D11 CryptoContract id")
struct D11_CryptoContractIdTests {
    // the design's literal: "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    private let usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

    // "`chain.id + \":\" + address`"
    @Test func contractIdIsChainIdColonAddress() {
        let usdc = EthereumContract(address: usdcAddress)
        #expect(usdc.id == EthereumChain.default.id + ":" + usdc.address)
        #expect(usdc.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
    }

    // "the address lower-cased by your initializer"
    @Test func tokenAddressIsLowerCased() {
        let shouted = "0x" + usdcAddress.dropFirst(2).uppercased()
        #expect(EthereumContract(address: shouted).address == usdcAddress)
        #expect(EthereumContract(address: shouted).id == EthereumContract(address: usdcAddress).id)
    }

    // "A chain's coin is `EthereumChain.default.mainContract`, address `\"eth\"`"
    @Test func ethereumsCoinIsTheMainContract() {
        let eth = EthereumChain.default.mainContract
        #expect(eth?.address == "eth")
        #expect(eth?.isChainToken == true)
        #expect(eth?.id == "eip155:1:eth")
    }

    // "A token is its contract" — not the chain's token
    @Test func aTokenIsNotTheChainToken() {
        let usdc = EthereumContract(address: usdcAddress)
        #expect(!usdc.isChainToken)
        #expect(usdc.isToken)
    }

    // "as your `==` compares chain and address"
    @Test func contractsWithOneChainAndAddressAreEqual() {
        #expect(EthereumContract(address: usdcAddress) == EthereumContract(address: usdcAddress))
    }

    // "`eip155:1:eth`. Optimism's is `eip155:10:eth`, a different instance of the same asset"
    @Test func optimismsCoinIsAnotherInstance() {
        // invented: OptimismChain — the 2023 conformer's class name is not quoted in the design
        #expect(OptimismChain.default.mainContract?.id == "eip155:10:eth")
        #expect(OptimismChain.default.mainContract?.id != EthereumChain.default.mainContract?.id)
    }

    // "`ZeroAmountChain` keeps the reflected default."
    @Test func zeroAmountChainKeepsTheReflectedDefault() {
        let zero = EthereumChain.zero
        #expect(zero.id == String(reflecting: ZeroAmountChain.self))
    }

    // "The reflected Swift type name is never stored." — no conformer of the seven answers with the reflected name
    @Test func noChainAnswersWithItsReflectedName() {
        #expect(EthereumChain.default.id != String(reflecting: EthereumChain.self))
        #expect(BitcoinChain.default.id != String(reflecting: BitcoinChain.self))
    }
}
