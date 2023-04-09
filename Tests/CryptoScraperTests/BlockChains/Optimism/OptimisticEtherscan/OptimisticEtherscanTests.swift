// OptimisticEtherscanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class OptimisticEtherscanTests: XCTestCase {
    private static let optContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["OPTIMISTIC_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment OPTIMISTIC_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = OptimismContract(address: OptimisticEtherscanTests.optContractAddress)

    private static let optimisticEtherscan = OptimisticEtherscan()
    private var optimismScan: OptimisticEtherscan { OptimisticEtherscanTests.optimisticEtherscan! }

    func testGetAccountBalance() async throws {
        let balance = try await optimismScan.getBalance(forAccount: accountContract)
        XCTAssertGreaterThan(balance.quantity, 0)

        let optBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
        XCTAssertGreaterThan(optBalance, 0)
    }

    func testGetTransactions() async throws {
        let transactions = try await optimismScan.getTransactions(forAccount: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }

    func testGetTokenBalance_OPT() async throws {
        let optToken = accountContract.chain.mainContract!

        do {
            let optBalance = try await optimismScan.getBalance(forToken: optToken, forAccount: accountContract)
            XCTAssertGreaterThan(optBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
