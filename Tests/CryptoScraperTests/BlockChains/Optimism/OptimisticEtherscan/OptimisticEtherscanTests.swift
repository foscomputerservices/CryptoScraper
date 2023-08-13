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
        sleep(2) // Overcomes rate limiting

        do {
            let transactions = try await optimismScan.getTransactions(
                forAccount: accountContract
            )
            XCTAssertGreaterThan(transactions.count, 0)
        } catch let e as EthereumScannerResponseError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("*************************************************")
                print("*** Error: Unable to test, rate-limit reached ***")
                print("*************************************************")
            }
        }
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

    func testGetTokenBalance_wBTC() async throws {
        let wBtcToken = OptimismContract(address: "0x68f180fcce6836688e9084f035309e29bf0a2095")

        do {
            let wBtcBalance = try await optimismScan.getBalance(forToken: wBtcToken, forAccount: accountContract)
            XCTAssertGreaterThan(wBtcBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenTransactions_wBTC() async throws {
        let wBtcToken = OptimismContract(address: "0x68f180fcce6836688e9084f035309e29bf0a2095")

        do {
            let wBtcTxns = try await optimismScan.getERC20Transactions(forToken: wBtcToken, forAccount: accountContract)
            XCTAssertGreaterThan(wBtcTxns.count, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
