// D18 — The identity stubs, in the nested form.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 1.8: "A holding on a reserved-fake chain, for a
// test that does not care which" and "Every default is a self-marking literal (R11): a `bedrock` namespace no registry
// holds, the Flintstones' quarry, 42." and "No default calls the enclosing type's own `stub()`".

import CryptoAsset
import Foundation
import Testing

@Suite("D18 Identity stubs")
struct D18_IdentityStubsTests {
    // "public static func stub() -> Self { .stub(chainId: \"bedrock:42\") }"
    @Test func instanceStubIsOnBedrock() {
        #expect(AssetInstance.stub().chainId == "bedrock:42")
    }

    // "address: String = \"quarry-42\""
    @Test func instanceStubAddressIsTheQuarry() {
        #expect(AssetInstance.stub().address == "quarry-42")
    }

    // "chain.id + \":\" + address" — the stub's id composes the two
    @Test func instanceStubIdComposes() {
        let stub = AssetInstance.stub()
        #expect(stub.id == "bedrock:42" + ":" + "quarry-42")
    }

    // "stub(chainId:address:)" — overriding one keeps the other at its fake
    @Test func instanceStubOverrideKeepsTheRest() {
        let slate = AssetInstance.stub(address: "slate-42")
        #expect(slate.chainId == "bedrock:42")
        #expect(slate.address == "slate-42")
    }

    // "a `bedrock` namespace no registry holds"
    @Test func bedrockIsNotAnOwnedNamespace() {
        #expect(!AssetRegistry.ownedNamespaces.contains("bedrock"))
    }

    // "a `bedrock` namespace no registry holds" — the shared registry declares nothing on it
    @Test func sharedRegistryDoesNotDeclareTheStub() {
        #expect(throws: AssetRegistryError.undeclaredInstance(.stub())) {
            try AssetRegistry.shared.decimals(of: .stub())
        }
    }

    // "public static func stub() -> Self { .stub(home: .stub()) }" on Asset
    @Test func assetStubHomeIsTheInstanceStub() {
        #expect(Asset.stub().id == AssetInstance.stub().id)
    }

    // "public static func stub(home: AssetInstance = .stub()) -> Self"
    @Test func assetStubFollowsItsHome() {
        let home = AssetInstance.stub(address: "slate-42")
        #expect(Asset.stub(home: home).id == home.id)
    }

    // "Every default is a self-marking literal" — the stub validates as an identity
    @Test func instanceStubValidates() throws {
        let stub = AssetInstance.stub()
        #expect(try AssetInstance(validating: stub.id) == stub)
    }
}
