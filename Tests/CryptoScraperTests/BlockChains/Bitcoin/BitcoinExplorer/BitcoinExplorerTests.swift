// BitcoinExplorerTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSFoundation
import XCTest

final class BitcoinExplorerTests: XCTestCase {
    private static let btcContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["BTC_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment BTC_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = BitcoinContract(address: BitcoinExplorerTests.btcContractAddress)

    private static let bitcoinExplorer = BitcoinExplorer()
    private var bitcoinExplorer: BitcoinExplorer { BitcoinExplorerTests.bitcoinExplorer }

    func testGetAccountBalance() async throws {
        let balance = try await bitcoinExplorer.getBalance(forAccount: accountContract)
        XCTAssertGreaterThan(balance.quantity, 0)

        let btcBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .btc)
        XCTAssertGreaterThan(btcBalance, 0)
    }

    func testGetTransactions() async throws {
        do {
            let transactions = try await bitcoinExplorer.getTransactions(
                forAccount: accountContract
            )
            XCTAssertGreaterThan(transactions.count, 0)
//
//            for txn in transactions {
//                print(txn.dumpIt(accountContract: accountContract))
//            }
        } catch let e as BitcoinExplorerResponseError {
            XCTFail("Error: \(e.localizedDescription)")
        } catch let e as DataFetchError {
            switch e {
            case .badStatus(let httpStatusCode):
                // Pretty flaky service, will have to find something else
                if httpStatusCode == 503 { return }
            default:
                XCTFail("Error: \(e.localizedDescription)")
            }
        } catch let e {
            XCTFail("Error: \(e.localizedDescription)")
        }
    }
}

private extension CryptoTransaction {
    func dumpIt(accountContract: BitcoinContract) {
        print("\(transactionId) -- \(timeStamp): \(accountContract.displayAmount(amount: amount.quantity, inUnits: .btc)) BTC")
        print("   From: \(fromContract?.address ?? "??") -> \(toContract?.address ?? "??")")
        print("   Fee: \(gasPrice == nil ? 0 : accountContract.displayAmount(amount: gasPrice!.quantity, inUnits: .satoshi)) SAT")
    }
}
