// TwoAmountsNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import Testing

/// Brief § 4 "Silences the build decides": two `Amount` types meet once a file imports both modules. Neither is
/// renamed; CryptoAsset's is written `CryptoAsset.Amount`. That this file compiles is the test.
@Suite struct TwoAmountsNoNetworkTests {
    @Test func aFileImportingBothModulesNamesEachAmount() async throws {
        let counted: CryptoAsset.Amount = .init(baseUnits: 1_000_000, of: EIP155.Ethereum.usdc.instance)
        let scanned = try await NilScanner<EthereumContract>().getBalance(forAccount: .stub())

        let usdc = try EthereumContract(address: #require(EIP155.Ethereum.usdc.instance.address))
        #expect(counted.instance == AssetInstance(usdc))
        #expect(scanned.quantity == 0)
    }
}
