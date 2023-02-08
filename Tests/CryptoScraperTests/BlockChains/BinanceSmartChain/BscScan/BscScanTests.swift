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

    private static let bscScan = BscScan()
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
        let transactions = try await bscScan.getTransactions(forAccount: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }

    func testGetTokenBalance_BNB() async throws {
        let bnbToken = accountContract.chain.mainContract!

        do {
            let bnbBalance = try await bscScan.getBalance(forToken: bnbToken, forAccount: accountContract)
            XCTAssertGreaterThan(bnbBalance.quantity, 0)
            print("*** BNB balance \(bnbBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_FET() async throws {
        let fetToken = BNBContract(address: "0x031b41e504677879370e9DBcF937283A8691Fa7f")

        do {
            let bnbBalance = try await bscScan.getBalance(forToken: fetToken, forAccount: accountContract)
            XCTAssertGreaterThan(bnbBalance.quantity, 0)
            XCTAssertEqual(bnbBalance.contract.address, fetToken.address)
            print("*** BNB balance \(bnbBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
