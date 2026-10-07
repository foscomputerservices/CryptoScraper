// StacksChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Stacks: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct StacksChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(StacksChain.default.id == "stacks:1")
        #expect(StacksChain.default.id == STACKS.Stacks.chainId)
        let instance = try AssetInstance(validating: StacksChain.default.id + ":" + "shape")
        #expect(instance.chainId == StacksChain.default.id)
        #expect(StacksChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(StacksChain.default.mainContract.isChainToken)
        #expect(StacksChain.default.mainContract.address == "stx")
        #expect(AssetInstance(StacksChain.default.mainContract).id == STACKS.Stacks.stx.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(StacksChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(STACKS.Stacks.stx.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(STACKS.Stacks.stx))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(StacksChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == STACKS.Stacks.stx)
        #expect(declaration.symbol.text == "STX")
        #expect(declaration.tokenName == "Stacks")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(StacksContract.Units.stx.divisorFromBase == Self.tenToThe(STACKS.Stacks.stx.decimals))
        #expect(StacksContract.Units.defaultDisplayUnits == .stx)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(StacksContract.Units.microstx.divisorFromBase == Self.tenToThe(0))
        #expect(StacksContract.Units.chainBaseUnits == .microstx)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try StacksChain.default.contract(for: "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP").address == "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP")
    }

    @Test(arguments: ["sp36qfqet18qp57mbsx0x4d3ascsm2wzh31ct78dp", "ST36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP", "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DPI", "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP.1token"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try StacksChain.default.contract(for: address) }
    }

    /// The boot address, its leading zero bytes compressed, and a contract in CoinGecko's form
    @Test(arguments: ["SP000000000000000000002Q6VF78", "SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD",
                      "SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc"])
    func aPrincipalOrAContractIsKeptAsGiven(_ address: String) throws {
        #expect(try StacksChain.default.contract(for: address).address == address)
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try StacksChain.default.contract(for: "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP")
        let decoded: StacksContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == StacksChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(StacksChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? StacksContract)
        #expect(contract == StacksChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: StacksChain.default.id + ":" + "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP")
        let contract = try #require(BlockChains.contract(of: account) as? StacksContract)
        #expect(contract.address == "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "stacks", by: .coinGecko) == StacksChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "stacks")?.chainId == StacksChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(StacksChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(StacksChain.default.scanner.userReadableName == "Hiro")
    }

    /// The recorded boot address: 3,173,325,509 microSTX at STX's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Hiro.BalancesResponse = try CoinGeckoRecorded.data("Stacks/balances.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 3_173_325_509)
        #expect(amount.currency == StacksChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded transactions: two STX transfers of 1 microSTX to the boot address, and a contract call, which
    /// moves no STX; each fee its sender's
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try StacksChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Stacks/transactions.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: StacksContract.self) }
        #expect(reads.map(\.quantity) == [1, 0, 1])
        #expect(reads.map(\.fee) == [200_000, 50_000, 200_000])
        #expect(reads.map(\.type) == ["token_transfer", "contract_call", "token_transfer"])
        #expect(reads.map(\.to) == ["SP000000000000000000002Q6VF78", nil, "SP000000000000000000002Q6VF78"])
        #expect(reads.allSatisfy { $0.currency == StacksChain.default.mainContract && $0.successful })
        #expect(reads[0].from == "SP36QFQET18QP57MBSX0X4D3ASCSM2WZH31CT78DP")
        #expect(reads[0].hash == "0x988bce32fa69801e4e0804ded6f63c5e6303c3b28de9b0714f7852120fc467bc")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_791_054_053))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try StacksChain.default.contract(for: "SP000000000000000000002Q6VF78")
        let token = try StacksChain.default.contract(for: "SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc")
        await #expect(throws: HiroResponseError.self) {
            try await StacksChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
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
