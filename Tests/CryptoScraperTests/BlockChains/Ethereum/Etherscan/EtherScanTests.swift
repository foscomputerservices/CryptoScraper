// EtherScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

@testable import CryptoScraper
import XCTest

final class EtherScanTests: XCTestCase {
    static let ethContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["ETH_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment ETH_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    let accountContract: EthereumContract = .init(address: EtherScanTests.ethContractAddress, chain: .ethereum)

    func testGetAccountBalance() async throws {
        let etherScan = Etherscan()

        let balance = try await etherScan.getAccountBalance(address: accountContract)
        XCTAssertGreaterThan(balance.quantity, 0)

        let ethBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
        XCTAssertGreaterThan(ethBalance, 0)
    }

    func testGetTransactions() async throws {
        let etherScan = Etherscan()

        let transactions = try await etherScan.getTransactions(address: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }
}
