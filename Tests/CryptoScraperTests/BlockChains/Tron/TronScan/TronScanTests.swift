// TronScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class TronScanTests: XCTestCase {
    private static let tronContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["TRON_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment TRON_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    private let accountContract = TronContract(address: TronScanTests.tronContractAddress)

    private static let tronScan = TronScan()
    private var tronScan: TronScan { TronScanTests.tronScan }

    func testGetAccountBalance() async throws {
        do {
            let balance = try await tronScan.getBalance(forAccount: accountContract)
            XCTAssertGreaterThan(balance.quantity, 0)

            let trxBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
            XCTAssertGreaterThan(trxBalance, 0)
        } catch let e as EthereumScannerResponseError {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTransactions() async throws {
        let transactions = try await tronScan.getTransactions(forAccount: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }

    func testGetTokenBalance_TRX() async throws {
        let trxToken = accountContract.chain.mainContract!

        do {
            let trxBalance = try await tronScan.getBalance(forToken: trxToken, forAccount: accountContract)
            XCTAssertGreaterThan(trxBalance.quantity, 0)
            print("*** TRX balance \(trxBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_Klever() async throws {
        let kleverToken = TronContract(address: "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS")

        do {
            let trxBalance = try await tronScan.getBalance(forToken: kleverToken, forAccount: accountContract)
            XCTAssertGreaterThan(trxBalance.quantity, 0)
            XCTAssertEqual(trxBalance.contract.address, kleverToken.address)
            print("*** Klever TRX balance \(trxBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
