// FTMScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class FTMScanTests: XCTestCase {
    static let ftmContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["FTM_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment FTM_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = FantomContract(address: FTMScanTests.ftmContractAddress)

    func testGetAccountBalance() async throws {
        let ftmScan = FTMScan()

        do {
            let balance = try await ftmScan.getBalance(forAccount: accountContract)
            XCTAssertGreaterThan(balance.quantity, 0)

            let ftmBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
            XCTAssertGreaterThan(ftmBalance, 0)
        } catch let e as FTMScanResponseError {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTransactions() async throws {
        let ftmScan = FTMScan()

        let transactions = try await ftmScan.getTransactions(forAccount: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }

    func testGetTokenBalance_FTM() async throws {
        let ftmScan = FTMScan()
        let ftmToken = accountContract.chain.mainContract!

        do {
            let ftmBalance = try await ftmScan.getBalance(forToken: ftmToken, forAccount: accountContract)
            XCTAssertGreaterThan(ftmBalance.quantity, 0)
            print("*** Fantom balance \(ftmBalance.quantity)")
        } catch let e as FTMScanResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_tShare() async throws {
        let ftmScan = FTMScan()
        let tShareToken = FantomContract(address: "0x4cdF39285D7Ca8eB3f090fDA0C069ba5F4145B37")

        do {
            let ftmBalance = try await ftmScan.getBalance(forToken: tShareToken, forAccount: accountContract)
            XCTAssertGreaterThan(ftmBalance.quantity, 0)
            print("*** Fantom balance \(ftmBalance.quantity)")
        } catch let e as FTMScanResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
