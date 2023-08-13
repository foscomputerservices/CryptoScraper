// PolygonScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class PolygonScanTests: XCTestCase {
    private static let maticContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["POLYGON_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment POLYGON_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    private let accountContract = MaticContract(address: PolygonScanTests.maticContractAddress)

    private static let polygonScan = PolygonScan()!
    private var polygonScan: PolygonScan { PolygonScanTests.polygonScan }

    func testGetAccountBalance() async throws {
        do {
            let balance = try await polygonScan.getBalance(forAccount: accountContract)
            XCTAssertGreaterThan(balance.quantity, 0)

            let maticBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
            XCTAssertGreaterThan(maticBalance, 0)
        } catch let e as EthereumScannerResponseError {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTransactions() async throws {
        sleep(2) // Overcomes rate limiting

        do {
            let transactions = try await polygonScan.getTransactions(
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

    func testGetTokenBalance_Matic() async throws {
        let maticToken = accountContract.chain.mainContract!

        do {
            let maticBalance = try await polygonScan.getBalance(forToken: maticToken, forAccount: accountContract)
            XCTAssertGreaterThan(maticBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_WrappedMatic() async throws {
        let wrappedMaticToken = MaticContract(address: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270")

        do {
            let wrappedMaticBalance = try await polygonScan.getBalance(forToken: wrappedMaticToken, forAccount: accountContract)
            XCTAssertGreaterThan(wrappedMaticBalance.quantity, 0)
            XCTAssertEqual(wrappedMaticBalance.contract.address, wrappedMaticToken.address)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenTransactions_WrappedMatic() async throws {
        let wrappedMaticToken = MaticContract(address: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270")

        do {
            let wMaticTxns = try await polygonScan.getERC20Transactions(forToken: wrappedMaticToken, forAccount: accountContract)
            XCTAssertGreaterThan(wMaticTxns.count, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
