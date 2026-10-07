// BlockchairNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Blockchair, the Bitcoin family's oracle (design § 2.5): the chains it serves, as its recorded `/stats` lists them,
/// and its address dashboard's reading, apart from any one chain. No network.
@Suite struct BlockchairNoNetworkTests {
    /// The chains Blockchair's recorded `/stats` (keyless, 2026-10-07) lists, by its slug for each
    static func servedSlugs() throws -> Set<String> {
        let json = try #require(
            JSONSerialization.jsonObject(with: CoinGeckoRecorded.data("Blockchair/stats.json")) as? [String: Any]
        )
        let data = try #require(json["data"] as? [String: Any])
        return Set(data.keys)
    }

    @Test func theRecordedStatsListTheFamilysServedChains() throws {
        let served = try Self.servedSlugs()
        #expect(served.isSuperset(of: ["bitcoin", "litecoin", "dogecoin", "bitcoin-cash", "dash", "zcash", "ecash"]))
        #expect(served.isDisjoint(with: ["digibyte", "ravencoin", "verge", "qtum"]))
    }

    @Test func theEndPointIsBlockchairsPublicAPI() {
        #expect(Blockchair<LitecoinContract>.endPoint.absoluteString == "https://api.blockchair.com")
    }

    /// A refusal that states no words is thrown with its code
    @Test func aRefusalWithNoWordsSaysItsCode() throws {
        let response: Blockchair<LitecoinContract>.DashboardResponse = try Data(#"{"data":null,"context":{"code":402}}"#.utf8).fromJSON()
        let error = #expect(throws: BlockchairResponseError.self) { try response.amount() }
        guard case .requestFailed(let words)? = error else {
            Issue.record("the refusal is not requestFailed: \(String(describing: error))")
            return
        }
        #expect(words == "Blockchair answered code 402 with no address")
    }

    /// Blockchair's time is UTC, written `yyyy-MM-dd HH:mm:ss`
    @Test func blockchairsTimeIsUTC() {
        #expect(Blockchair<LitecoinContract>.DashboardResponse.date("2026-01-01 00:00:00") == Date(timeIntervalSince1970: 1_767_225_600))
        #expect(Blockchair<LitecoinContract>.DashboardResponse.date("2026-01-01T00:00:00Z") == nil)
        #expect(Blockchair<LitecoinContract>.DashboardResponse.date("yesterday") == nil)
    }

    /// An empty answer holds no transactions
    @Test func anEmptyAnswerHoldsNoTransactions() throws {
        #expect(try LitecoinChain.default.scanner.loadTransactions(from: Data()).isEmpty)
    }
}
