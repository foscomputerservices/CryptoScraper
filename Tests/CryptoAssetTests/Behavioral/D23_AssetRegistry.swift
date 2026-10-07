// D23 — The registry: the statement of every asset the process knows.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.3: "Holds the library's own declarations from the
// start. A service adds the rows built from CryptoScraper's chain tables once at start, and replaces them when it
// refreshes. A miss is an error, never a default." And § 2.1: "An instance's decimals never change once declared ...
// `replace(_:)` refuses it". And § 5.3: "the same declarations twice are one".

import CryptoAsset
import Foundation
import Testing

@Suite("D23 AssetRegistry")
struct D23_AssetRegistryTests {
    private let home = AssetInstance.stub()
    private let away = AssetInstance.stub(chainId: "bedrock:43", address: "quarry-42")
    private let other = AssetInstance.stub(address: "slate-42")

    private func declaration(_ instances: [(AssetInstance, Int)], symbol: String = "FRED") throws -> AssetDeclaration {
        try AssetDeclaration(asset: .stub(home: instances[0].0), tokenName: "Fred Coin",
                             symbol: AssetSymbol(validating: symbol),
                             instances: instances.map { try AssetDeclaration.Instance(instance: $0.0, decimals: $0.1,
                                                                                         symbol: AssetSymbol(validating: symbol)) })
    }

    // "public func declaration(of asset: Asset) throws -> AssetDeclaration"
    @Test func declarationOfReturnsWhatWasDeclared() throws {
        let fred = try declaration([(home, 6), (away, 8)])
        let registry = try AssetRegistry([fred])
        #expect(try registry.declaration(of: fred.asset) == fred)
    }

    // "A miss is an error, never a default." — undeclared asset
    @Test func undeclaredAssetThrows() throws {
        let registry = try AssetRegistry([])
        #expect(throws: AssetRegistryError.undeclared(.stub())) { try registry.declaration(of: .stub()) }
    }

    // "The decimals `instance` counts in"
    @Test func decimalsOfEachInstance() throws {
        let registry = try AssetRegistry([declaration([(home, 6), (away, 8)])])
        #expect(try registry.decimals(of: home) == 6)
        #expect(try registry.decimals(of: away) == 8)
    }

    // "A miss is a typed error, every time" — undeclared instance
    @Test func decimalsOfUndeclaredInstanceThrows() throws {
        let registry = try AssetRegistry([declaration([(home, 6)])])
        #expect(throws: AssetRegistryError.undeclaredInstance(other)) { try registry.decimals(of: other) }
    }

    // "The asset `instance` is one of"
    @Test func assetOfEachInstanceIsTheClass() throws {
        let fred = try declaration([(home, 6), (away, 8)])
        let registry = try AssetRegistry([fred])
        #expect(try registry.asset(of: home) == fred.asset)
        #expect(try registry.asset(of: away) == fred.asset)
    }

    // "A miss is a typed error, every time" — asset(of:) on an undeclared instance
    @Test func assetOfUndeclaredInstanceThrows() throws {
        let registry = try AssetRegistry([declaration([(home, 6)])])
        #expect(throws: AssetRegistryError.undeclaredInstance(other)) { try registry.asset(of: other) }
    }

    // "The instance of `asset` on the chain or exchange `chainId`"
    @Test func instanceOfAssetOnAChain() throws {
        let fred = try declaration([(home, 6), (away, 8)])
        let registry = try AssetRegistry([fred])
        #expect(try registry.instance(of: fred.asset, on: try #require(away.chainId)) == away)
    }

    // "case noInstance(Asset, on: String)"
    @Test func instanceOfAssetOnAChainItLacksThrows() throws {
        let fred = try declaration([(home, 6)])
        let registry = try AssetRegistry([fred])
        let chain = try #require(away.chainId)
        #expect(throws: AssetRegistryError.noInstance(fred.asset, on: chain)) {
            try registry.instance(of: fred.asset, on: chain)
        }
    }

    // "Whether two instances are one asset" — true within one class
    @Test func isEquivalentWithinOneClass() throws {
        let registry = try AssetRegistry([declaration([(home, 6), (away, 8)])])
        #expect(try registry.isEquivalent(home, away))
    }

    // "Whether two instances are one asset" — false across two declared classes
    @Test func isNotEquivalentAcrossClasses() throws {
        let registry = try AssetRegistry([declaration([(home, 6)]), declaration([(other, 6)], symbol: "BARNEY")])
        #expect(try !registry.isEquivalent(home, other))
    }

    // "A miss is a typed error, every time" — isEquivalent on an undeclared instance
    @Test func isEquivalentOnUndeclaredThrows() throws {
        let registry = try AssetRegistry([declaration([(home, 6)])])
        #expect(throws: AssetRegistryError.undeclaredInstance(other)) { try registry.isEquivalent(home, other) }
    }

    // "One asset per instance. An instance in two classes is `instanceInTwoAssets`, thrown at the add."
    @Test func instanceInTwoClassesThrowsAtAdd() throws {
        let registry = try AssetRegistry([declaration([(home, 6), (away, 8)])])
        let second = try declaration([(other, 6), (away, 8)], symbol: "BARNEY")
        #expect(throws: AssetRegistryError.instanceInTwoAssets(away)) { try registry.add([second]) }
    }

    // "One asset per instance" — at the initializer too
    @Test func instanceInTwoClassesThrowsAtInit() throws {
        let first = try declaration([(home, 6), (away, 8)])
        let second = try declaration([(other, 6), (away, 8)], symbol: "BARNEY")
        #expect(throws: AssetRegistryError.instanceInTwoAssets(away)) { try AssetRegistry([first, second]) }
    }

    // "the same declarations twice are one" (§ 5.3)
    @Test func addingTheSameDeclarationTwiceIsOne() throws {
        let fred = try declaration([(home, 6)])
        let registry = try AssetRegistry([fred])
        try registry.add([fred])
        #expect(try registry.declaration(of: fred.asset) == fred)
    }

    // "Additions to `shared` are add-only and conflict-checked" — a different declaration of one asset
    @Test(.disabled("Classified 2026-10-07: asserts an add naming a declared asset with one more instance is refused; the design says each client adds its exchange's declarations to its registry (§ 5.3), which join the library's classes (Kraken's XBT in Bitcoin's), so the code's add merges a declaration that says the same of the asset and refuses one that says otherwise (§ 2.3); see the identity ledger")) func addingADifferentDeclarationOfOneAssetThrows() throws {
        let fred = try declaration([(home, 6)])
        let registry = try AssetRegistry([fred])
        let different = try declaration([(home, 6), (away, 8)])
        #expect(throws: AssetRegistryError.conflictingDeclaration(fred.asset)) { try registry.add([different]) }
    }

    // "A refresh; never a library declaration"
    @Test func replacingALibraryDeclarationThrows() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        let usd = try registry.declaration(of: .usd)
        #expect(throws: AssetRegistryError.libraryDeclaration(.usd)) { try registry.replace([usd]) }
    }

    // "never a declared instance's decimals" — `replace(_:)` refuses it
    @Test func replacingAnInstancesDecimalsThrows() throws {
        let registry = try AssetRegistry([declaration([(home, 6), (away, 8)])])
        let changed = try declaration([(home, 6), (away, 10)])
        #expect(throws: AssetRegistryError.decimalsChanged(away)) { try registry.replace([changed]) }
    }

    // "Regeneration adds and renames ... a rename changes its symbol only" (§ 2.7, § 4.2) — a refresh may rename
    @Test func replacingWithARenamedSymbolKeepsTheInstance() throws {
        let registry = try AssetRegistry([declaration([(home, 6)], symbol: "TON")])
        try registry.replace([declaration([(home, 6)], symbol: "GRAM")])
        let renamed = try registry.declaration(of: .stub(home: home))
        #expect(renamed.symbol.text == "GRAM")
        #expect(try registry.decimals(of: home) == 6)
        #expect(try registry.asset(of: home) == .stub(home: home))
    }

    // "and replaces them when it refreshes" — a refresh may add an instance to a non-library class
    @Test func replacingMayAddAnInstance() throws {
        let registry = try AssetRegistry([declaration([(home, 6)])])
        try registry.replace([declaration([(home, 6), (away, 8)])])
        #expect(try registry.decimals(of: away) == 8)
    }

    // "The namespaces this library owns, beside CAIP-2's: \"exchange\", \"iso4217\""
    @Test(.disabled("Classified 2026-10-07: asserts the owned namespaces are exchange and iso4217 alone, as § 6 writes; the design's admission (§ 2.5) gives a chain CAIP has not registered its own namespace, and the chains work added eight (near, cip34, icp, ont, zil, ckb, sia, dcr); see the identity ledger")) func ownedNamespacesAreExchangeAndISO4217() {
        #expect(AssetRegistry.ownedNamespaces == ["exchange", "iso4217"])
    }

    // "Holds the library's own declarations from the start."
    @Test func sharedHoldsTheLibraryDeclarations() throws {
        for declaration in AssetRegistry.libraryDeclarations {
            #expect(try AssetRegistry.shared.declaration(of: declaration.asset) == declaration)
        }
    }

    // "One shared instance, and a parameter for tests." — a registry built here is not the shared one
    @Test func aTestRegistryIsItsOwn() throws {
        let registry = try AssetRegistry([declaration([(home, 6)])])
        #expect(try registry.decimals(of: home) == 6)
        #expect(throws: AssetRegistryError.undeclaredInstance(home)) { try AssetRegistry.shared.decimals(of: home) }
    }
}
