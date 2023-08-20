// BlockChainInfoTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class BlockChainInfoTests: XCTestCase {
    private static let btcContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["BTC_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment BTC_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = BitcoinContract(address: BlockChainInfoTests.btcContractAddress)

    private static let blockChainInfo = BlockChainInfo()
    private var blockChainInfo: BlockChainInfo { BlockChainInfoTests.blockChainInfo }

    // TODO: Restore when we figure out display
//    func testGetAccountBalance() async throws {
//        let balance = try await blockChainInfo.getBalance(forAccount: accountContract)
//        XCTAssertGreaterThan(balance.quantity, 0)
//
//        let btcBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .btc)
//        XCTAssertGreaterThan(btcBalance, 0)
//    }

    func testGetTransactions() async throws {
        do {
            let transactions = try await blockChainInfo.getTransactions(forAccount: accountContract)
            XCTAssertGreaterThan(transactions.count, 0)
//
//            for txn in transactions {
//                print(txn.dumpIt(accountContract: accountContract))
//            }
        } catch let e as BlockChainInfoResponseError {
            XCTFail("Error: \(e.localizedDescription)")
        }
    }
}

private extension CryptoTransaction {
    func dumpIt(accountContract: BitcoinContract) {
        // TODO: Restore when we figure out display
//        print("\(transactionId) -- \(timeStamp): \(accountContract.displayAmount(amount: amount.quantity, inUnits: .btc)) BTC")
//        print("   From: \(fromContract?.address ?? "??") -> \(toContract?.address ?? "??")")
//        print("   Fee: \(gasPrice == nil ? 0 : accountContract.displayAmount(amount: gasPrice!.quantity, inUnits: .satoshi)) SAT")
    }
}
