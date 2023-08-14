// FTMScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class FTMScanTests: XCTestCase {
    private static let ftmContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["FTM_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment FTM_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    private let accountContract = FantomContract(address: FTMScanTests.ftmContractAddress)

    private static let ftmScan = FTMScan()!
    private var ftmScan: FTMScan { FTMScanTests.ftmScan }

    func testGetAccountBalance() async throws {
        do {
            let balance = try await ftmScan.getBalance(forAccount: accountContract)
            XCTAssertGreaterThan(balance.quantity, 0)

            let ftmBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
            XCTAssertGreaterThan(ftmBalance, 0)
        } catch let e as EthereumScannerResponseError {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTransactions() async throws {
        sleep(2) // Overcomes rate limiting

        do {
            let transactions = try await ftmScan.getTransactions(
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

    func testGetTokenBalance_FTM() async throws {
        let ftmToken = accountContract.chain.mainContract!

        do {
            let ftmBalance = try await ftmScan.getBalance(forToken: ftmToken, forAccount: accountContract)
            XCTAssertGreaterThan(ftmBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_tShare() async throws {
        let tShareToken = FantomContract(address: "0x4cdF39285D7Ca8eB3f090fDA0C069ba5F4145B37")

        do {
            let ftmBalance = try await ftmScan.getBalance(forToken: tShareToken, forAccount: accountContract)
            XCTAssertGreaterThan(ftmBalance.quantity, 0)
            XCTAssertEqual(ftmBalance.contract.address, tShareToken.address)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenTransactions_tShare() async throws {
        let tShareToken = FantomContract(address: "0x4cdF39285D7Ca8eB3f090fDA0C069ba5F4145B37")

        do {
            let tShareTxns = try await ftmScan.getERC20Transactions(forToken: tShareToken, forAccount: accountContract)
            XCTAssertGreaterThan(tShareTxns.count, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
