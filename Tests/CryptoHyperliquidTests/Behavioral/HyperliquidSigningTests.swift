// HyperliquidSigningTests.swift — AR33: the client's payload construction proven byte for byte against known-good signatures.
//
// THE FIXTURE: `hyperliquid-signing-vectors.json` in this test target's bundle (a resource of the target).
// It is made by the POC's own signing code over a throwaway key bound to no account, never the POC's agent key (T40).
// Its shape, every field required unless marked optional:
//
// {
//   "agentPrivateKeyHex": "0x…64 hex…",          // the throwaway agent key that signed every vector
//   "agentAddress":       "0x…40 hex…",          // its address, lowercase (T41: the agent signs)
//   "vectors": [
//     {
//       "name":             "order BTC buy IOC on a sub-account",    // a label for the failure message
//       "actionJSON":       "{\"type\":\"order\",…}",               // the action exactly as the POC sent it, as a JSON STRING
//                                                                  // so its key order survives (the encoding signed is ordered)
//       "actionMsgpackHex": "0x…",               // the action's MessagePack bytes, the encoding signed over
//       "nonce":            1727000000000,       // the nonce, milliseconds, as sent
//       "isMainnet":        false,               // the chain: false is the test market ("b"), true the main one ("a")
//       "vaultAddress":     "0x…" | null,        // the sub-account the action is for, or null for the signer's own
//       "actionHashHex":    "0x…64 hex…",        // keccak256(msgpack ‖ nonce as 8 bytes big-endian ‖ vault flag and address)
//       "typedDataHashHex": "0x…64 hex…",        // the EIP-712 digest of the phantom agent over that hash, the bytes signed
//       "r":                "0x…64 hex…",        // the secp256k1 signature, as the POC put it in the request
//       "s":                "0x…64 hex…",
//       "v":                27 | 28,
//       "call": {                                // optional: the C31 call that must produce this exact action
//         // exactly one of:
//         "placeOrder":  { "market": "BTC", "isBuy": true, "size": "0.00123", "limit": "64300.5",
//                          "immediateOrCancel": true, "reduceOnly": false, "account": "0x…" },
//         "cancelOrder": { "market": "BTC", "orderId": 77738310, "account": "0x…" },
//         "setLeverage": { "market": "BTC", "leverage": 5, "isolated": true, "account": "0x…" },
//         "transfer":    { "amount": "500.25", "from": "0x…", "to": "0x…" }
//       },
//       "assetIndexJSON": "{\"universe\":[…]}"   // optional with "call": the meta answer the POC saw, so the asset index matches
//     }
//   ]
// }
//
// Every action the agent signs is an L1 action (order, cancel, updateLeverage, subAccountTransfer): AR33 says the agent
// cannot withdraw or change the approval, which are the user-signed actions; so one signing scheme covers the fixture.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import Foundation
import Testing

// MARK: - The fixture's shape

struct SigningVectors: Decodable {
    let agentPrivateKeyHex: String
    let agentAddress: String
    let vectors: [SigningVector]
}

struct SigningVector: Decodable, CustomTestStringConvertible {
    let name: String
    let actionJSON: String
    let actionMsgpackHex: String
    let nonce: UInt64
    let isMainnet: Bool
    let vaultAddress: String?
    let actionHashHex: String
    let typedDataHashHex: String
    let r: String
    let s: String
    let v: Int
    let call: SigningCall?
    let assetIndexJSON: String?

    var testDescription: String { name }
}

struct SigningCall: Decodable {
    struct PlaceOrder: Decodable {
        let market: String
        let isBuy: Bool
        let size: String
        let limit: String
        let immediateOrCancel: Bool
        let reduceOnly: Bool
        let account: String
    }
    struct CancelOrder: Decodable {
        let market: String
        let orderId: HyperliquidClient.OrderId
        let account: String
    }
    struct SetLeverage: Decodable {
        let market: String
        let leverage: Int
        let isolated: Bool
        let account: String
    }
    struct Transfer: Decodable {
        let amount: String
        let from: String
        let to: String
    }
    let placeOrder: PlaceOrder?
    let cancelOrder: CancelOrder?
    let setLeverage: SetLeverage?
    let transfer: Transfer?
}

enum FixtureError: Error {
    case missing
    case badHex(String)
}

func loadSigningVectors() throws -> SigningVectors {
    guard let url = Bundle.module.url(forResource: "hyperliquid-signing-vectors", withExtension: "json") else {
        throw FixtureError.missing
    }
    return try JSONDecoder().decode(SigningVectors.self, from: Data(contentsOf: url))
}

/// The bytes of a 0x-prefixed (or bare) hex text
func hexBytes(_ text: String) throws -> Data {
    let digits = text.hasPrefix("0x") || text.hasPrefix("0X") ? String(text.dropFirst(2)) : text
    guard digits.count.isMultiple(of: 2) else { throw FixtureError.badHex(text) }
    var bytes = Data(capacity: digits.count / 2)
    var index = digits.startIndex
    while index < digits.endIndex {
        let next = digits.index(index, offsetBy: 2)
        guard let byte = UInt8(digits[index..<next], radix: 16) else { throw FixtureError.badHex(text) }
        bytes.append(byte)
        index = next
    }
    return bytes
}

/// The vectors, for parameterized tests; an unreadable fixture is a failure, never an empty list
func signingVectorsOrRecord() -> [SigningVector] {
    do {
        return try loadSigningVectors().vectors
    } catch {
        Issue.record("the signing fixture could not be read: \(error)")
        return []
    }
}

// MARK: - The tests

@Suite("AR33: Hyperliquid's signing, byte for byte")
struct HyperliquidSigningTests {

    @Test("AR33: the fixture is present and holds vectors")
    func fixtureIsPresent() throws {
        let fixture = try loadSigningVectors()
        #expect(!fixture.vectors.isEmpty)
    }

    @Test("AR33, T41: the agent key's address is the fixture's agent: the agent signs")
    func agentAddressMatches() throws {
        let fixture = try loadSigningVectors()
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:), the client's signing seam
        #expect(signer.address.lowercased() == fixture.agentAddress.lowercased()) // INVENTED: HyperliquidSigner.address
    }

    @Test("AR33: the action's encoding is the POC's, byte for byte", arguments: signingVectorsOrRecord())
    func actionEncoding(vector: SigningVector) throws {
        let fixture = try loadSigningVectors()
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let signed = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(actionJSON:nonce:vaultAddress:isMainnet:) -> a signed action
        #expect(signed.actionBytes == (try hexBytes(vector.actionMsgpackHex))) // INVENTED: the signed action's actionBytes
    }

    @Test("AR33: the action hash, nonce and vault included, is the POC's", arguments: signingVectorsOrRecord())
    func actionHash(vector: SigningVector) throws {
        let fixture = try loadSigningVectors()
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let signed = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(…)
        #expect(signed.actionHash == (try hexBytes(vector.actionHashHex))) // INVENTED: the signed action's actionHash
    }

    @Test("AR33: the typed-data hash signed over is the POC's", arguments: signingVectorsOrRecord())
    func typedDataHash(vector: SigningVector) throws {
        let fixture = try loadSigningVectors()
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let signed = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(…)
        #expect(signed.typedDataHash == (try hexBytes(vector.typedDataHashHex))) // INVENTED: the signed action's typedDataHash
    }

    @Test("AR33: r, s and v are the POC's", arguments: signingVectorsOrRecord())
    func signature(vector: SigningVector) throws {
        let fixture = try loadSigningVectors()
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let signed = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(…)
        #expect(signed.r == (try hexBytes(vector.r))) // INVENTED: the signed action's r
        #expect(signed.s == (try hexBytes(vector.s))) // INVENTED: the signed action's s
        #expect(signed.v == vector.v) // INVENTED: the signed action's v
    }

    @Test("AR33: the same action at the same nonce signs to the same bytes (deterministic)")
    func signingIsDeterministic() throws {
        let fixture = try loadSigningVectors()
        let vector = try #require(fixture.vectors.first)
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let once = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(…)
        let twice = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: vector.isMainnet) // INVENTED: HyperliquidSigner.sign(…)
        #expect(once.r == twice.r) // INVENTED: r
        #expect(once.s == twice.s) // INVENTED: s
    }

    @Test("AR33: the chain is part of what is signed: the main market and the test market differ")
    func chainIsSigned() throws {
        let fixture = try loadSigningVectors()
        let vector = try #require(fixture.vectors.first)
        let signer = try HyperliquidSigner(agentKey: HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)) // INVENTED: HyperliquidSigner(agentKey:)
        let main = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: true) // INVENTED: HyperliquidSigner.sign(…)
        let test = try signer.sign(actionJSON: Data(vector.actionJSON.utf8), nonce: vector.nonce, vaultAddress: vector.vaultAddress, isMainnet: false) // INVENTED: HyperliquidSigner.sign(…)
        #expect(main.actionHash == test.actionHash) // INVENTED: actionHash
        #expect(main.typedDataHash != test.typedDataHash) // INVENTED: typedDataHash
    }

    @Test("AR33: C31's own calls build the POC's action and carry its signature", arguments: signingVectorsOrRecord().filter { $0.call != nil && !$0.isMainnet })
    func clientCallsCarryTheSignature(vector: SigningVector) async throws {
        let fixture = try loadSigningVectors()
        let call = try #require(vector.call)
        var routes: [ScriptedRoute] = []
        if let meta = vector.assetIndexJSON {
            routes.append(.json("\"meta\"", meta))
        }
        routes += HyperliquidScript.info + [.json("", #"{"status":"ok","response":{"type":"default"}}"#)]
        let session = ScriptedSession(routes)
        let client = try HyperliquidClient(credential: .agentKey(HyperliquidAgentKey(hex: fixture.agentPrivateKeyHex)), endpoint: .testMarket, session: session, log: { _ in }, nonce: { vector.nonce }) // INVENTED: the `log:` and `nonce:` parameters, a fixed clock for the nonce

        if let order = call.placeOrder {
            _ = try await client.placeOrder(
                market: order.market, side: order.isBuy ? .buy : .sell, size: amount(order.size, order.market), limit: price(order.limit, "USDC"),
                immediateOrCancel: order.immediateOrCancel, reduceOnly: order.reduceOnly, account: order.account
            )
        } else if let cancel = call.cancelOrder {
            try await client.cancelOrder(cancel.orderId, market: cancel.market, account: cancel.account)
        } else if let leverage = call.setLeverage {
            try await client.setLeverage(leverage.leverage, market: leverage.market, isolated: leverage.isolated, account: leverage.account)
        } else if let transfer = call.transfer {
            try await client.transfer(amount(transfer.amount, "USDC"), from: transfer.from, to: transfer.to)
        } else {
            Issue.record("a call names none of the four")
        }

        let sent = session.everythingSent.lowercased()
        #expect(sent.contains(vector.r.lowercased()))
        #expect(sent.contains(vector.s.lowercased()))
        #expect(sent.contains(String(vector.nonce)))
    }
}
