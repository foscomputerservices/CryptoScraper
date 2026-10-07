// NeoChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Neo: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct NeoChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(NeoChain.default.id == "neo:860833102")
        #expect(NeoChain.default.id == NEO.Neo.chainId)
        let instance = try AssetInstance(validating: NeoChain.default.id + ":" + "shape")
        #expect(instance.chainId == NeoChain.default.id)
        #expect(NeoChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(NeoChain.default.mainContract.isChainToken)
        #expect(NeoChain.default.mainContract.address == "neo")
        #expect(AssetInstance(NeoChain.default.mainContract).id == NEO.Neo.neo.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(NeoChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 0)
        #expect(NEO.Neo.neo.decimals == 0)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(NEO.Neo.neo))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(NeoChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == NEO.Neo.neo)
        #expect(declaration.symbol.text == "NEO")
        #expect(declaration.tokenName == "Neo")
    }

    /// GAS, the chain's second native coin, under its own placeholder and its own declaration (design § 2.5)
    @Test func gasIsItsOwnDeclaredInstanceOnTheChain() throws {
        let gas = try NeoChain.default.contract(for: "gas")
        #expect(!gas.isChainToken)
        #expect(AssetInstance(gas).id == NEO.Neo.gas.instance.id)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(gas)) == 8)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: AssetInstance(gas)))
        #expect(declaration.instances.first == NEO.Neo.gas)
        #expect(declaration.symbol.text == "GAS")
        #expect(try !AssetRegistry.shared.isEquivalent(AssetInstance(gas), AssetInstance(NeoChain.default.mainContract)))
        let back = try #require(BlockChains.contract(of: NEO.Neo.gas.instance) as? NeoContract)
        #expect(back == gas)
    }

    // MARK: The ladder against the statement (design § 2.2)

    /// NEO is indivisible: its one unit is the base unit and the whole unit, ten to the declared zero
    @Test func theOneUnitIsTenToTheDeclaredZero() {
        #expect(NeoContract.Units.neo.divisorFromBase == Self.tenToThe(NEO.Neo.neo.decimals))
        #expect(NeoContract.Units.chainBaseUnits == .neo)
        #expect(NeoContract.Units.defaultDisplayUnits == .neo)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try NeoChain.default.contract(for: "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ").address == "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
    }

    @Test(arguments: ["AikhQp1aAD1YFCiwknhM5LQQebj4464bCJ", "NikhQp1aAD1YFCiwknhM5LQQebj4464bC0", "0xef4073a0f2b305a38ec4050e4d3d28bc40ea63f"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try NeoChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try NeoChain.default.contract(for: "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
        let decoded: NeoContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == NeoChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(NeoChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? NeoContract)
        #expect(contract == NeoChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: NeoChain.default.id + ":" + "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
        let contract = try #require(BlockChains.contract(of: account) as? NeoContract)
        #expect(contract.address == "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "neo", by: .coinGecko) == NeoChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "neo")?.chainId == NeoChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "Neo", by: .coinMarketCap) == NeoChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(NeoChain.default.scanner.userReadableName == "Neo RPC")
    }

    /// The node's recorded `getversion` states the Network Magic the id is made of
    @Test func theNodeStatesTheNetworkMagicOfTheId() throws {
        struct Version: Decodable { let protocol_: Protocol_; enum CodingKeys: String, CodingKey { case protocol_ = "protocol" } }
        struct Protocol_: Decodable { let network: UInt32 }
        let response: NeoRPC.Response<Version> = try CoinGeckoRecorded.data("Neo/getversion.json").fromJSON()
        #expect(try "neo:\(response.value().protocol_.network)" == NeoChain.default.id)
    }

    /// The node's recorded `getnativecontracts` states NEO's and GAS's script hashes as the scanner reads them
    @Test func theNodeStatesTheCoinsScriptHashes() throws {
        struct Native: Decodable { let hash: String; let manifest: Manifest }
        struct Manifest: Decodable { let name: String }
        let response: NeoRPC.Response<[Native]> = try CoinGeckoRecorded.data("Neo/getnativecontracts.json").fromJSON()
        let byName = try Dictionary(uniqueKeysWithValues: response.value().map { ($0.manifest.name, $0.hash) })
        #expect(NeoRPC.scriptHash(of: NeoChain.default.mainContract) == byName["NeoToken"])
        #expect(try NeoRPC.scriptHash(of: NeoChain.default.contract(for: "gas")) == byName["GasToken"])
    }

    /// The recorded balances list one row named "GAS" at another contract's hash: NEO and GAS are matched by their
    /// native hashes, never by a symbol, so the account holds none of either, and the other token is its own
    @Test func theRecordedBalancesAreMatchedByScriptHashNeverBySymbol() throws {
        let response: NeoRPC.Response<NeoRPC.BalancesResponse> = try CoinGeckoRecorded.data("Neo/getnep17balances.json").fromJSON()
        let balances = try response.value()
        #expect(balances.balance.map(\.symbol) == ["GAS"])
        #expect(try balances.amount(of: NeoChain.default.mainContract).quantity == 0)
        #expect(try balances.amount(of: NeoChain.default.contract(for: "gas")).quantity == 0)
        let other = try NeoChain.default.contract(for: "0xb249c1c038545a9e9d223f54accd85e457e4909e")
        #expect(try balances.amount(of: other).quantity == 10_000_000_000_000_000)
    }

    /// The recorded transfers are empty in the node's default window of seven days
    @Test func theRecordedTransfersAreEmpty() throws {
        #expect(try NeoChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Neo/getnep17transfers.json")).isEmpty)
    }

    /// NOT A RECORDING: `getnep17transfers` in the shape the Neo documentation gives, its values made up (the recorded
    /// answer is empty), one GAS transfer received, to show the mapping; GAS by its native hash is the chain's GAS,
    /// at its declared 8
    @Test func aTransferInTheDocumentedShapeMapsToGas() throws {
        let documented = """
        {"jsonrpc":"2.0","id":1,"result":{"sent":[],"received":[{"timestamp":1612690268736,"assethash":"0xd2a4cff31913016155e38e474a2c06d08be276cf","transferaddress":"NVfJmhP28Q9qva9Tdtpt3af4H1a3cp7Lih","amount":"100000000","blockindex":525,"transfernotifyindex":0,"txhash":"0x0000000000000000000000000000000000000000000000000000000000000000"}],"address":"NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ"}}
        """
        let transactions = try NeoChain.default.scanner.loadTransactions(from: Data(documented.utf8))
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: NeoContract.self)
        let gas = try NeoChain.default.contract(for: "gas")
        #expect(read.currency == gas)
        #expect(read.quantity == 100_000_000)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(gas)) == 8)
        #expect(read.from == "NVfJmhP28Q9qva9Tdtpt3af4H1a3cp7Lih")
        #expect(read.to == "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
    }

    @Test func anAccountsBalanceAsATokenIsNotRead() async throws {
        let account = try NeoChain.default.contract(for: "NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ")
        await #expect(throws: NeoRPCResponseError.self) {
            try await NeoChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    /// CoinMarketCap lists GAS on Neo at "0x0", an address the chain refuses, so it is left out of the list
    @Test func coinMarketCapsGasAtZeroIsLeftOut() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 1785, "name": "Gas", "symbol": "GAS", "slug": "gas", "is_active": 1,
              "first_historical_data": "2017-07-11T00:00:00.000Z",
              "platform": { "id": 1376, "name": "Neo", "symbol": "NEO", "slug": "neo", "token_address": "0x0" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: NeoContract.self).isEmpty)
    }

    /// One mapped transaction's facts, its existential opened: its amount's currency read as `C`
    private static func reading<C: CryptoContract>(
        _ transaction: some CryptoTransaction, as _: C.Type
    ) -> (hash: String, quantity: Int128, currency: C?, from: String?, to: String?, fee: Int128?, successful: Bool,
          timeStamp: Date, type: String?) {
        (transaction.hash, transaction.amount.quantity, transaction.amount.currency as? C,
         transaction.fromContract?.address, transaction.toContract?.address, transaction.gasPrice?.quantity,
         transaction.successful, transaction.timeStamp, transaction.type)
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
