// BscScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class BscScanTests: XCTestCase {
    static let bnbContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["BSC_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment BSC_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = BNBContract(address: BscScanTests.bnbContractAddress)

    private static let bscScan = BscScan()!
    private var bscScan: BscScan { BscScanTests.bscScan }

    func testGetAccountBalance() async throws {
        do {
            let balance = try await bscScan.getBalance(forAccount: accountContract)
            XCTAssertGreaterThan(balance.quantity, 0)

            let bnbBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
            XCTAssertGreaterThan(bnbBalance, 0)
        } catch let e as EthereumScannerResponseError {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTransactions() async throws {
        sleep(2) // Overcomes rate limiting

        do {
            let transactions = try await bscScan.getTransactions(forAccount: accountContract)
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

    func testGetTokenBalance_BNB() async throws {
        let bnbToken = accountContract.chain.mainContract!

        do {
            let bnbBalance = try await bscScan.getBalance(forToken: bnbToken, forAccount: accountContract)
            XCTAssertGreaterThan(bnbBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
