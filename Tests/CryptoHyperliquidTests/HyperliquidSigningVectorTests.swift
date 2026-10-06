// HyperliquidSigningVectorTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
@testable import CryptoHyperliquid
import CryptoOHLCV
import Foundation
import Testing

// AR33: the payload construction, the action encoding and the typed-data hash signed over, proven byte for byte
// against the POC's SDK on the same payloads, for the test market and production.

@Suite("AR33: Hyperliquid's signing against the POC's vectors")
struct HyperliquidSigningVectorTests {
    static let file = VectorFile.loaded

    @Test func theFixtureNamesItsOriginAndHoldsBothChains() {
        #expect(Self.file.origin.contains("poc/harness/hyperliquid-signing-vectors.ts"))
        #expect(Self.file.vectors.count == 14)
        #expect(Set(Self.file.vectors.map(\.isMainnet)) == [false, true])
        #expect(Self.file.userSignedVectors.count == 4)
    }

    @Test func theAgentsAddressIsDerivedFromItsKey() {
        #expect(Self.file.key.address == Self.file.agentAddress)
    }

    @Test(arguments: VectorFile.loaded.vectors)
    func anL1ActionEncodesHashesAndSignsToThePOCsBytes(vector: L1Vector) throws {
        let action = OrderedJSON.parse(vector.actionJSON)
        #expect(action.json == vector.actionJSON)
        #expect(hexText(action.messagePack) == vector.actionMsgpackHex)

        let hash = try HyperliquidSigning.actionHash(action, nonce: vector.nonce, vaultAddress: vector.vaultAddress)
        #expect(hexText(hash) == vector.actionHashHex)
        let digest = HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: vector.isMainnet)
        #expect(hexText(digest) == vector.typedDataHashHex)

        let signature = Self.file.key.sign(digest: digest)
        #expect(hexText(signature.r) == vector.r)
        #expect(hexText(signature.s) == vector.s)
        #expect(signature.v == vector.v)
    }

    @Test(arguments: VectorFile.loaded.userSignedVectors)
    func aUserSignedActionHashesAndSignsToThePOCsBytes(vector: UserSignedVector) throws {
        let fields = try #require(JSONSerialization.jsonObject(with: Data(vector.actionJSON.utf8)) as? [String: Any])
        let chain = fields["hyperliquidChain"] as! String
        let nonce = (fields["nonce"] as! NSNumber).uint64Value
        let typed: [HyperliquidSigning.TypedField] = vector.primaryType.hasSuffix("ApproveAgent")
            ? [.string("hyperliquidChain", chain), .address("agentAddress", fields["agentAddress"] as! String),
               .string("agentName", fields["agentName"] as! String), .uint64("nonce", nonce)]
            : [.string("hyperliquidChain", chain), .string("amount", fields["amount"] as! String),
               .bool("toPerp", fields["toPerp"] as! Bool), .uint64("nonce", nonce)]
        let chainId = UInt64((fields["signatureChainId"] as! String).dropFirst(2), radix: 16)!

        let digest = try HyperliquidSigning.userSignedDigest(primaryType: vector.primaryType, fields: typed, signatureChainId: chainId)
        #expect(hexText(digest) == vector.typedDataHashHex)
        let signature = Self.file.key.sign(digest: digest)
        #expect(hexText(signature.r) == vector.r)
        #expect(hexText(signature.s) == vector.s)
        #expect(signature.v == vector.v)
    }

    @Test func theClientsOwnBuildersMakeThePOCsActions() {
        let byName = Dictionary(Self.file.vectors.filter { !$0.isMainnet }.map { ($0.name, $0.actionJSON) }, uniquingKeysWith: { first, _ in first })
        let built: [(String, HyperliquidWireValue)] = [
            ("order: limit IOC buy BTC on a sub-account (test market)",
             HyperliquidActions.order(asset: 3, isBuy: true, limit: "64300.5", size: "0.00123", reduceOnly: false, timeInForce: "Ioc")),
            ("order: reduce-only IOC sell ETH on a sub-account (test market)",
             HyperliquidActions.order(asset: 4, isBuy: false, limit: "2650.1", size: "0.0088", reduceOnly: true, timeInForce: "Ioc")),
            ("order: resting GTC buy BTC on the signer's own account (test market)",
             HyperliquidActions.order(asset: 3, isBuy: true, limit: "60000", size: "0.001", reduceOnly: false, timeInForce: "Gtc")),
            ("cancel: one BTC order on a sub-account (test market)", HyperliquidActions.cancel(asset: 3, oid: 77_738_310)),
            ("leverage: BTC isolated at 5x on a sub-account (test market)", HyperliquidActions.updateLeverage(asset: 3, isCross: false, leverage: 5)),
            ("sub-account transfer: 500.25 USDC into a sub-account (test market)",
             HyperliquidActions.subAccountTransfer(subAccount: "0x00000000000000000000000000000000000f00d2", isDeposit: true, microUSD: 500_250_000)),
        ]
        for (name, action) in built {
            #expect(action.json == byName[name], "\(name)")
        }
    }

    @Test func theSameDigestSignsToTheSameBytesAndTheChainChangesTheDigest() throws {
        let vector = try #require(Self.file.vectors.first)
        let action = OrderedJSON.parse(vector.actionJSON)
        let hash = try HyperliquidSigning.actionHash(action, nonce: vector.nonce, vaultAddress: vector.vaultAddress)
        let test = HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: false)
        #expect(Self.file.key.sign(digest: test) == Self.file.key.sign(digest: test))
        #expect(test != HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: true))
    }

    @Test func theKeyNamesNoByteOfItselfInItsDescriptionOrItsReflection() {
        let key = Self.file.key
        let secret = String(Self.file.agentPrivateKeyHex.dropFirst(2))
        for text in [key.description, key.debugDescription, String(reflecting: key), "\(key)", String(describing: Mirror(reflecting: key).children.map(\.value))] {
            #expect(!text.lowercased().contains(secret.prefix(16)))
        }
    }

    @Test func aKeyThatIsNotASecp256k1SecretIsRefused() {
        #expect(throws: HyperliquidClientError.malformedAgentKey) { try HyperliquidAgentKey(privateKey: Data(repeating: 0, count: 32)) }
        #expect(throws: HyperliquidClientError.malformedAgentKey) { try HyperliquidAgentKey(privateKey: Data(repeating: 1, count: 31)) }
    }
}
