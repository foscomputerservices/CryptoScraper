// D12 — Each chain declares its CAIP-2 id.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.2: "Each conformer states its id, which satisfies
// your protocol's `Identifiable` requirement in place of the reflected default" and its seven ids. And § 6: "Its id is
// pinned to its CAIP-2 string, and has the CAIP-2 shape."

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D12 Chain ids")
struct D12_ChainIdsTests {
    // invented: the CAIP-2 pattern written in the test, from the standard the design cites (namespace [-a-z0-9]{3,8}, reference [-_a-zA-Z0-9]{1,32})
    private func hasCAIP2Shape(_ id: String) -> Bool {
        id.wholeMatch(of: /[-a-z0-9]{3,8}:[-_a-zA-Z0-9]{1,32}/) != nil
    }

    // "Bitcoin: `bip122:000000000019d6689c085ae165831e93`."
    @Test func bitcoin() {
        #expect(BitcoinChain.default.id == "bip122:000000000019d6689c085ae165831e93")
        #expect(hasCAIP2Shape(BitcoinChain.default.id))
    }

    // "Ethereum: `eip155:1`."
    @Test func ethereum() {
        #expect(EthereumChain.default.id == "eip155:1")
        #expect(hasCAIP2Shape(EthereumChain.default.id))
    }

    // "BNB Smart Chain: `eip155:56`."
    @Test func bnbSmartChain() {
        // invented: BNBChain — the 2023 conformer's class name is not quoted in the design
        #expect(BNBChain.default.id == "eip155:56")
        #expect(hasCAIP2Shape(BNBChain.default.id))
    }

    // "Polygon PoS: `eip155:137`."
    @Test func polygon() {
        // invented: PolygonChain — as above
        #expect(PolygonChain.default.id == "eip155:137")
        #expect(hasCAIP2Shape(PolygonChain.default.id))
    }

    // "Optimism: `eip155:10`."
    @Test func optimism() {
        // invented: OptimismChain — as above
        #expect(OptimismChain.default.id == "eip155:10")
        #expect(hasCAIP2Shape(OptimismChain.default.id))
    }

    // "Fantom Opera: `eip155:250`."
    @Test func fantom() {
        // invented: FantomChain — as above
        #expect(FantomChain.default.id == "eip155:250")
        #expect(hasCAIP2Shape(FantomChain.default.id))
    }

    // "Tron: `tron:728126428`. ... the namespace's reference is the decimal form"
    @Test func tron() {
        // invented: TronChain — the design quotes TronContract and TronScan; the chain class's name is not quoted
        #expect(TronChain.default.id == "tron:728126428")
        #expect(hasCAIP2Shape(TronChain.default.id))
    }

    // "A chain's id appears in the library only on its conformer." — the conformer and the generated constant agree
    @Test func conformerAndGeneratedConstantAgree() {
        #expect(EthereumChain.default.id == EIP155.Ethereum.chainId)
        #expect(PolygonChain.default.id == EIP155.Polygon.chainId)
    }

    // "so it can never equal a chain's id" — the seven ids are distinct
    @Test func theSevenAreDistinct() {
        let ids = [BitcoinChain.default.id, EthereumChain.default.id, BNBChain.default.id, PolygonChain.default.id,
                   OptimismChain.default.id, FantomChain.default.id, TronChain.default.id]
        #expect(Set(ids).count == 7)
    }

    // "The library's table of the namespaces it owns holds `exchange` and `iso4217`" — no chain uses one
    @Test func noChainUsesAnOwnedNamespace() {
        for id in [BitcoinChain.default.id, EthereumChain.default.id, TronChain.default.id] {
            #expect(!AssetRegistry.ownedNamespaces.contains(String(id.prefix { $0 != ":" })))
        }
    }

    // "no owned namespace appears in the CAIP namespaces registry's recorded list"
    @Test func ownedNamespacesAreNotInCAIPsRecordedList() throws {
        // invented: CAIPRecording.namespaces() — the recorded list of the CAIP namespaces registry; its loader is not declared
        let registered = try CAIPRecording.namespaces()
        #expect(AssetRegistry.ownedNamespaces.isDisjoint(with: registered))
    }
}
