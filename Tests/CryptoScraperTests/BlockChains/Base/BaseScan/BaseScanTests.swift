// BaseScanTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import XCTest

/// Base's scanner against Etherscan's API V2, live, with the owner's key (network, not gating). V2 serves the
/// chain to a paid plan only, so with a free key every test is skipped in V2's words; token info, the oracle of a
/// token's decimals, needs a Standard key.
final class BaseScanTests: XCTestCase {
    // A public address every EVM chain has: the conventional burn address
    let accountContract = BaseContract(address: "0x000000000000000000000000000000000000dEaD")

    private static let baseScan = BaseScan()
    private var baseScan: BaseScan { BaseScanTests.baseScan }

    // One key, one rate, and a chain V2 may refuse to the key's plan: each test is skipped in V2's words when it does.
    override func setUp() async throws {
        sleep(1) // One key, one rate: V2 answers a free key 3 calls a second across every chain
        try await skipWhereEtherscanV2Refuses { _ = try await baseScan.getBalance(forAccount: accountContract) }
    }

    func testGetAccountBalance() async throws {
        let balance = try await baseScan.getBalance(forAccount: accountContract)
        XCTAssertGreaterThanOrEqual(balance.quantity, 0)
    }

    /// The oracle (design § 2.5, § 6): V2's divisor for USDC on Base is the statement's decimals
    func testGetInfo_USDCsDivisorIsTheDeclaredDecimals() async throws {
        let usdc = try BaseChain.default.contract(for: XCTUnwrap(EIP155.Base.usdCoin.instance.address))

        try await skipWhereEtherscanV2Refuses { _ = try await baseScan.getInfo(forToken: usdc) }
        let info = try await baseScan.getInfo(forToken: usdc)
        XCTAssertEqual(info.decimals, EIP155.Base.usdCoin.decimals)
    }
}
