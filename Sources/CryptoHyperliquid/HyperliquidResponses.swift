// HyperliquidResponses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import Foundation

// The parts of Hyperliquid's answers the client reads, shaped as its JSON. Every number Hyperliquid sends as text is
// decoded here into an exact WireDecimal; no text survives the decode as a number.

struct HyperliquidMeta: Decodable, Sendable {
    struct Coin: Decodable, Sendable {
        let name: String
        let szDecimals: Int
        let maxLeverage: Int?
        let isDelisted: Bool?
    }

    let universe: [Coin]
}

// `metaAndAssetCtxs`: [meta, [context per coin, in meta's order]].
struct HyperliquidMetaAndContexts: Decodable, Sendable {
    struct Context: Decodable, Sendable {
        let markPx: WireDecimal?
        let midPx: WireDecimal?
        let dayBaseVlm: WireDecimal
        let dayNtlVlm: WireDecimal
    }

    let meta: HyperliquidMeta
    let contexts: [Context]

    init(from decoder: any Decoder) throws {
        var pair = try decoder.unkeyedContainer()
        self.meta = try pair.decode(HyperliquidMeta.self)
        self.contexts = try pair.decode([Context].self)
    }

    func context(of coin: String) -> Context? {
        guard let index = meta.universe.firstIndex(where: { $0.name == coin }), index < contexts.count else {
            return nil
        }
        return contexts[index]
    }
}

struct HyperliquidL2Book: Decodable, Sendable {
    struct Level: Decodable, Sendable {
        let px: WireDecimal
        let sz: WireDecimal
    }

    let time: Int64
    let levels: [[Level]]
}

struct HyperliquidOpenOrder: Decodable, Sendable {
    let coin: String
    let side: String
    let sz: WireDecimal
    let oid: Int64
    /// The client order id the order was placed with, 16 bytes as "0x" and 32 hex digits; absent where none was
    let cloid: String?
}

struct HyperliquidClearinghouseState: Decodable, Sendable {
    struct Summary: Decodable, Sendable {
        let accountValue: WireDecimal
    }

    struct AssetPosition: Decodable, Sendable {
        let position: Position
    }

    struct Position: Decodable, Sendable {
        let coin: String
        let szi: WireDecimal
        let leverage: Leverage?
        let entryPx: WireDecimal?
        let liquidationPx: WireDecimal?
    }

    // A position's leverage: {"type": "isolated" or "cross", "value": 2, …}.
    struct Leverage: Decodable, Sendable {
        let value: Int
    }

    let marginSummary: Summary
    let withdrawable: WireDecimal
    let assetPositions: [AssetPosition]
    let time: Int64
}

struct HyperliquidFill: Decodable, Sendable {
    let coin: String
    let px: WireDecimal
    let sz: WireDecimal
    let side: String
    let time: Int64
    let dir: String
    let oid: Int64
    /// Hyperliquid's trade id; read where present
    let tid: Int64?
    let fee: WireDecimal
    let liquidation: Bool

    private enum CodingKeys: String, CodingKey {
        case coin, px, sz, side, time, dir, oid, tid, fee, liquidation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.coin = try container.decode(String.self, forKey: .coin)
        self.px = try container.decode(WireDecimal.self, forKey: .px)
        self.sz = try container.decode(WireDecimal.self, forKey: .sz)
        self.side = try container.decode(String.self, forKey: .side)
        self.time = try container.decode(Int64.self, forKey: .time)
        self.dir = try container.decode(String.self, forKey: .dir)
        self.oid = try container.decode(Int64.self, forKey: .oid)
        self.tid = try container.decodeIfPresent(Int64.self, forKey: .tid)
        self.fee = try container.decode(WireDecimal.self, forKey: .fee)
        // A fill that closed a position by liquidation carries a `liquidation` object; any other carries none.
        self.liquidation = try container.contains(.liquidation) && !container.decodeNil(forKey: .liquidation)
    }
}

struct HyperliquidFunding: Decodable, Sendable {
    struct Delta: Decodable, Sendable {
        let coin: String
        let usdc: WireDecimal
        let fundingRate: WireDecimal
    }

    let time: Int64
    let delta: Delta
}

// `userNonFundingLedgerUpdates`: each item's `delta` by its `type`, the kinds C30 carries read, the others kept as other.
struct HyperliquidLedgerUpdate: Decodable, Sendable {
    enum Delta: Sendable {
        case deposit(WireDecimal)
        case withdrawal(WireDecimal)
        case move(WireDecimal, from: String, to: String)
        case other
    }

    let time: Int64
    let hash: String?
    let delta: Delta

    private enum CodingKeys: String, CodingKey {
        case time, hash, delta
    }

    private enum DeltaKeys: String, CodingKey {
        case type, usdc, user, destination, amount, toPerp
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decode(Int64.self, forKey: .time)
        self.hash = try container.decodeIfPresent(String.self, forKey: .hash)
        let delta = try container.nestedContainer(keyedBy: DeltaKeys.self, forKey: .delta)
        switch try delta.decode(String.self, forKey: .type) {
        case "deposit":
            self.delta = .deposit(try delta.decode(WireDecimal.self, forKey: .usdc))
        case "withdraw":
            self.delta = .withdrawal(try delta.decode(WireDecimal.self, forKey: .usdc))
        case "subAccountTransfer", "internalTransfer":
            self.delta = .move(try delta.decode(WireDecimal.self, forKey: .usdc),
                               from: try delta.decode(String.self, forKey: .user), to: try delta.decode(String.self, forKey: .destination))
        case "send":
            self.delta = .move(try delta.decode(WireDecimal.self, forKey: .amount),
                               from: try delta.decode(String.self, forKey: .user), to: try delta.decode(String.self, forKey: .destination))
        case "accountClassTransfer":
            let toPerp = try delta.decode(Bool.self, forKey: .toPerp)
            self.delta = .move(try delta.decode(WireDecimal.self, forKey: .usdc), from: toPerp ? "spot" : "perp", to: toPerp ? "perp" : "spot")
        default:
            self.delta = .other
        }
    }
}

struct HyperliquidAgent: Decodable, Sendable {
    let address: String
    let validUntil: Int64?
}

struct HyperliquidUserRole: Decodable, Sendable {
    struct Data_: Decodable, Sendable {
        let user: String
    }

    let role: String
    let data: Data_?
}

struct HyperliquidSubAccount: Decodable, Sendable {
    let name: String
    let subAccountUser: String
}

struct HyperliquidRateLimit: Decodable, Sendable {
    let nRequestsUsed: Int
    let nRequestsCap: Int
}

// The exchange endpoint's "ok" answer: `{"status":"ok","response":{"type":"order","data":{…}}}`; `data` is absent for
// the plain `{"type":"default"}`. An "err" status does not decode here, so the fetch reads it as HyperliquidAPIError.
struct HyperliquidExchangeAnswer<Payload: Decodable & Sendable>: Decodable, Sendable {
    struct Response: Decodable, Sendable {
        let data: Payload?
    }

    let response: Response

    private enum CodingKeys: String, CodingKey {
        case status, response
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .status) == "ok" else {
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Not an ok answer")
        }
        self.response = try container.decode(Response.self, forKey: .response)
    }
}

struct HyperliquidNoData: Decodable, Sendable {}

struct HyperliquidOrderStatuses: Decodable, Sendable {
    enum Status: Decodable, Sendable {
        case filled(totalSize: WireDecimal, averagePrice: WireDecimal, oid: Int64)
        case resting(oid: Int64)
        case error(String)

        private enum Keys: String, CodingKey {
            case filled, resting, error
        }

        private struct Filled: Decodable {
            let totalSz: WireDecimal
            let avgPx: WireDecimal
            let oid: Int64
        }

        private struct Resting: Decodable {
            let oid: Int64
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            if let filled = try container.decodeIfPresent(Filled.self, forKey: .filled) {
                self = .filled(totalSize: filled.totalSz, averagePrice: filled.avgPx, oid: filled.oid)
            } else if let resting = try container.decodeIfPresent(Resting.self, forKey: .resting) {
                self = .resting(oid: resting.oid)
            } else {
                self = .error(try container.decode(String.self, forKey: .error))
            }
        }
    }

    let statuses: [Status]
}

// A cancel's statuses: "success", or {"error": "…"}.
struct HyperliquidCancelStatuses: Decodable, Sendable {
    let refusal: String?

    private enum CodingKeys: String, CodingKey {
        case statuses
    }

    private struct Refused: Decodable {
        let error: String
    }

    init(from decoder: any Decoder) throws {
        var statuses = try decoder.container(keyedBy: CodingKeys.self).nestedUnkeyedContainer(forKey: .statuses)
        var refusal: String?
        while !statuses.isAtEnd {
            if let text = try? statuses.decode(String.self), text == "success" { // a status is either the text "success" or an error object
                continue
            }
            refusal = try statuses.decode(Refused.self).error
        }
        self.refusal = refusal
    }
}

// A JSON string answer, `"disabled"`: decoded as JSON, since FOSFoundation's fetch hands a `String` result up as the
// body's raw text, quotes and all.
struct HyperliquidJSONText: Decodable, Sendable {
    let text: String

    init(from decoder: any Decoder) throws {
        self.text = try decoder.singleValueContainer().decode(String.self)
    }
}
