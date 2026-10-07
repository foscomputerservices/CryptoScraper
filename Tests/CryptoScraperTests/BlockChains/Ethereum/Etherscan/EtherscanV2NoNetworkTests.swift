// EtherscanV2NoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

// Resources/Etherscan holds Etherscan API V2's answers, recorded once on 2026-10-07: chainlist.json from the keyless
// https://api.etherscan.io/v2/chainlist; the others asked of https://api.etherscan.io/v2/api with the owner's key, a
// free-tier key, read from the environment and stripped (no answer carries it): Ethereum's (chainid 1) balance of
// 0x…dead, its USDC token balance, its first three normal transactions (page=1&offset=3) and its first three USDC
// transfers (tokentx, page=1&offset=3); BNB Smart Chain's balance and normal transactions (chainid 56), each refused
// to a free key; Fantom's
// (chainid 250), refused as a chain V2 does not serve; and USDC's token info on Ethereum, refused to a free key as an
// API Pro endpoint. tokeninfo-documented-example.json is NOT a recording: it is the example answer of Etherscan's
// documentation (docs.etherscan.io, "Get Token Info by ContractAddress"), copied verbatim, the only token-info answer
// a free key can see.

/// The work item "The five Etherscan-family scanners move to Etherscan API V2" and design § 2.5, § 4.1, § 6: one V2
/// client, one key, each scanner a chain's configuration, and the scanner as the oracle of a token's decimals. No
/// network. Serialized: two tests set the one key, to a value that is not a key, and clear it. No expectation
/// captures a key or a URL that may carry one: each is compared first and only the answer is expected, so a failure
/// prints `false`, never the environment's key.
@Suite(.serialized) struct EtherscanV2NoNetworkTests {
    // MARK: One client, one key

    @Test func eachScannerAsksEtherscansOneV2Endpoint() {
        let v2 = URL(string: "https://api.etherscan.io/v2/api")!
        #expect(Etherscan.endPoint == v2)
        #expect(BscScan.endPoint == v2)
        #expect(PolygonScan.endPoint == v2)
        #expect(FTMScan.endPoint == v2)
        #expect(OptimisticEtherscan.endPoint == v2)
    }

    @Test func eachScannerStatesItsChainsId() {
        #expect(Etherscan.chainId == EthereumChain.default.id)
        #expect(BscScan.chainId == BinanceSmartChain.default.id)
        #expect(PolygonScan.chainId == PolygonChain.default.id)
        #expect(FTMScan.chainId == FantomChain.default.id)
        #expect(OptimisticEtherscan.chainId == OptimismChain.default.id)
    }

    @Test func theFiveScannersShareOneKey() {
        BscScan.apiKey = Self.notAKey
        defer { Etherscan.apiKey = nil }

        let etherscanReadsIt = Etherscan.apiKey == Self.notAKey
        let polygonScanReadsIt = PolygonScan.apiKey == Self.notAKey
        let ftmScanReadsIt = FTMScan.apiKey == Self.notAKey
        let optimisticEtherscanReadsIt = OptimisticEtherscan.apiKey == Self.notAKey
        #expect(etherscanReadsIt)
        #expect(polygonScanReadsIt)
        #expect(ftmScanReadsIt)
        #expect(optimisticEtherscanReadsIt)
        #expect(Set([
            Etherscan.apiKeyName, BscScan.apiKeyName, PolygonScan.apiKeyName, FTMScan.apiKeyName,
            OptimisticEtherscan.apiKeyName
        ]) == ["ETHER_SCAN_KEY"])
    }

    @Test func eachRequestNamesItsChainFirstAndTheKeyLast() throws {
        Etherscan.apiKey = Self.notAKey
        defer { Etherscan.apiKey = nil }

        let query = [URLQueryItem(name: "module", value: "account")]
        let asked: [(URL, String)] = try [
            (Etherscan.requestURL(query), "1"), (BscScan.requestURL(query), "56"),
            (PolygonScan.requestURL(query), "137"), (FTMScan.requestURL(query), "250"),
            (OptimisticEtherscan.requestURL(query), "10")
        ]
        for (url, chainid) in asked {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let host = components?.host
            let path = components?.path
            let names = components?.queryItems?.map(\.name)
            let firstValue = components?.queryItems?.first?.value
            let carriesTheKeySet = components?.queryItems?.last?.value == Self.notAKey
            #expect(host == "api.etherscan.io")
            #expect(path == "/v2/api")
            #expect(names == ["chainid", "module", "apikey"])
            #expect(firstValue == chainid)
            #expect(carriesTheKeySet)
        }
    }

    // MARK: What V2 serves (the keyless chain list, recorded)

    @Test func v2ServesFourOfTheFiveChainsAndNotFantoms() throws {
        let served = try Self.servedChainIds()
        #expect(served.isSuperset(of: ["1", "56", "137", "10"]))
        #expect(!served.contains("250"))
    }

    // MARK: The recorded answers, read as each read reads them

    @Test func theRecordedBalanceIsReadInWei() throws {
        let response: AccountResponse = try Self.recorded("balance-ethereum.json").fromJSON()
        let balance = try response.amount(forAccount: EthereumChain.default.mainContract)
        #expect(balance.quantity == 12_640_641_272_025_075_025_194)
        #expect(balance.currency == EthereumChain.default.mainContract)
    }

    @Test func theRecordedTokenBalanceIsInUSDCsBaseUnits() throws {
        let usdc = try EthereumChain.default.contract(for: #require(EIP155.Ethereum.usdc.instance.address))
        let response: TokenBalanceResponse = try Self.recorded("tokenbalance-ethereum-usdc.json").fromJSON()
        let balance = try response.cryptoBalance(forToken: usdc, ethContract: EthereumChain.default.mainContract)
        #expect(balance.quantity == 56_328_527_447)
        #expect(balance.currency == usdc)
    }

    @Test func theRecordedNormalTransactionsLoad() throws {
        let transactions = try Etherscan().loadTransactions(from: Self.recorded("txlist-ethereum.json"))
        #expect(transactions.count == 3)
        #expect(transactions.first?.hash == "0xe680803d2c85597984dc371e84a30ea8ac4a3333c3d1b51a6d432cb364dc469e")
    }

    @Test func aChainAFreeKeyCannotReadIsRefusedInV2sWords() throws {
        let response: AccountResponse = try Self.recorded("balance-bnb-smart-chain-free-key-refused.json").fromJSON()
        #expect(Self.refusal(of: { _ = try response.amount(forAccount: BinanceSmartChain.default.mainContract) })?
            .hasPrefix("Free API access is not supported for this chain") == true)
    }

    @Test func aFreeKeysTransactionsAreRefusedInV2sWords() throws {
        let response: TransactionResponse = try Self.recorded("txlist-bnb-smart-chain-free-key-refused.json").fromJSON()
        let mainContract = BinanceSmartChain.default.mainContract!
        #expect(Self.refusal(of: { _ = try response.cryptoTransactions(ethContract: mainContract) })?
            .contains("Free API access is not supported for this chain") == true)
    }

    @Test func fantomsChainIsRefusedAsOneV2DoesNotServe() throws {
        let response: AccountResponse = try Self.recorded("balance-fantom-unsupported-chain.json").fromJSON()
        #expect(Self.refusal(of: { _ = try response.amount(forAccount: FantomChain.default.mainContract) })?
            .hasPrefix("Missing or unsupported chainid parameter") == true)
    }

    // MARK: The oracle: a token's decimals from its chain's scanner

    @Test func aTokenInfosDecimalsAreItsDivisor() throws {
        let response: TokenInfoResponse = try Self.recorded("tokeninfo-documented-example.json").fromJSON()
        let info = try response.cryptoInfo(on: EthereumChain.default.mainContract)
        #expect(info.decimals == 0)
        #expect(info.tokenName == "Gods Unchained Cards")
        #expect(info.tokenType == "ERC721")
        #expect(info.contractAddress == EthereumContract(address: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"))
    }

    @Test func aFreeKeysTokenInfoIsRefusedAsAProEndpoint() throws {
        let response: TokenInfoResponse = try Self.recorded("tokeninfo-ethereum-usdc-free-key-refused.json").fromJSON()
        #expect(Self.refusal(of: { _ = try response.cryptoInfo(on: EthereumChain.default.mainContract) })?
            .contains("API Pro endpoint") == true)
    }

    /// The oracle a free key can read: each recorded USDC transfer states USDC's decimals, and they are the
    /// statement's
    @Test func etherscansUSDCTransfersStateTheDeclaredDecimals() throws {
        let answer = try #require(
            JSONSerialization.jsonObject(with: Self.recorded("tokentx-ethereum-usdc.json")) as? [String: Any]
        )
        let transfers = try #require(answer["result"] as? [[String: Any]])
        #expect(transfers.count == 3)
        for transfer in transfers {
            #expect(transfer["contractAddress"] as? String == EIP155.Ethereum.usdc.instance.address)
            #expect(transfer["tokenDecimal"] as? String == String(EIP155.Ethereum.usdc.decimals))
        }
    }

    // MARK: Helpers

    private static let notAKey = "fred-not-a-key"

    static func recorded(_ name: String) -> Data {
        CoinGeckoRecorded.data("Etherscan/" + name)
    }

    static func servedChainIds() throws -> Set<String> {
        let answer = try #require(
            JSONSerialization.jsonObject(with: recorded("chainlist.json")) as? [String: Any]
        )
        let chains = try #require(answer["result"] as? [[String: Any]])
        return Set(chains.compactMap { $0["chainid"] as? String })
    }

    /// The text of the `requestFailed` a read throws; `nil` when it throws nothing or anything else
    static func refusal(of read: () throws -> Void) -> String? {
        do {
            try read()
            return nil
        } catch let EthereumScannerResponseError.requestFailed(text) {
            return text
        } catch {
            return nil
        }
    }
}
