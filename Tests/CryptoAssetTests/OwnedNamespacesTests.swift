// OwnedNamespacesTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// Design § 1.3, § 1.4, § 2.5: the library's table of the namespaces it owns, "exchange" and "iso4217", and each
// chain's whose namespace CAIP's registry does not hold. If CAIP ever registers any, this is the one place the conflict
// is caught, read against the registry's recorded list.

@Suite("Owned namespaces")
struct OwnedNamespacesTests {
    @Test func theLibraryOwnsExchangeISO4217AndTheUnregisteredChainsNamespaces() {
        #expect(AssetRegistry.ownedNamespaces == [
            "exchange", "iso4217", "near", "cip34", "icp", "ont", "zil", "ckb", "sia", "dcr"
        ])
    }

    /// Each chain's owned namespace, its namespace enum's, absent from the registry's recorded list (read again
    /// 2026-10-07, the same 49)
    @Test(arguments: [
        NEAR.namespace, CIP34.namespace, ICP.namespace, ONT.namespace, ZIL.namespace, CKB.namespace, SIA.namespace,
        DCR.namespace
    ])
    func eachChainsOwnedNamespaceIsAbsentFromTheRegistry(namespace: String) {
        #expect(AssetRegistry.ownedNamespaces.contains(namespace))
        #expect(!Fixtures.caipNamespaces.contains(namespace))
    }

    @Test func noOwnedNamespaceIsInTheCAIPRegistry() {
        #expect(Fixtures.caipNamespaces.count == 49)
        #expect(Fixtures.caipNamespaces.isDisjoint(with: AssetRegistry.ownedNamespaces))
    }

    @Test func eachOwnedNamespaceHasTheCAIP2Shape() throws {
        for namespace in AssetRegistry.ownedNamespaces {
            #expect((3...8).contains(namespace.count))
            #expect(namespace.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        }
        #expect(try AssetInstance(validating: "exchange:kraken:XBT").chainId == "exchange:kraken")
    }

    @Test func theRegistrysRecordedListHoldsTheSevenChainsNamespaces() {
        // the fixture is the registry's list, not a made-up one: the namespaces of the seven chains are in it
        #expect(Fixtures.caipNamespaces.isSuperset(of: ["bip122", "eip155", "tron"]))
    }
}
