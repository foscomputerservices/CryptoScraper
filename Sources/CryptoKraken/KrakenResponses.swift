// KrakenResponses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import Foundation

// The parts of Kraken's answers the client reads, shaped as its JSON, each inside Kraken's `{"error":[],"result":…}`
// envelope (KrakenResult, from CryptoOHLCV). Every number Kraken sends as text is decoded here into an exact
// WireDecimal; a time Kraken sends as a JSON number of seconds is read as its text, exactly.

struct KrakenPairInfo: Decodable, Sendable {
    let altname: String
    let base: String
    let quote: String
    let lotDecimals: Int
    let ordermin: WireDecimal
    let leverageBuy: [Int]
    let status: String

    private enum CodingKeys: String, CodingKey {
        case altname, base, quote, ordermin, status
        case lotDecimals = "lot_decimals"
        case leverageBuy = "leverage_buy"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.altname = try container.decode(String.self, forKey: .altname)
        self.base = try container.decode(String.self, forKey: .base)
        self.quote = try container.decode(String.self, forKey: .quote)
        self.lotDecimals = try container.decode(Int.self, forKey: .lotDecimals)
        self.ordermin = try container.decode(WireDecimal.self, forKey: .ordermin)
        self.leverageBuy = try container.decodeIfPresent([Int].self, forKey: .leverageBuy) ?? []
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "online"
    }
}

struct KrakenAssetEntry: Decodable, Sendable {
    let altname: String
    let decimals: Int
}

// A ticker: a = [ask price, whole lot volume, lot volume], b = the bid's, v = [today's volume, the last 24 hours'].
struct KrakenTicker: Decodable, Sendable {
    let ask: WireDecimal
    let bid: WireDecimal
    let dayVolume: WireDecimal

    private enum CodingKeys: String, CodingKey {
        case a, b, v
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let ask = try container.decode([WireDecimal].self, forKey: .a).first,
              let bid = try container.decode([WireDecimal].self, forKey: .b).first,
              let volume = try container.decode([WireDecimal].self, forKey: .v).last else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "A ticker missing its ask, bid or volume"))
        }
        self.ask = ask
        self.bid = bid
        self.dayVolume = volume
    }
}

struct KrakenAddedOrder: Decodable, Sendable {
    let txid: [String]
}

struct KrakenOrderInfo: Decodable, Sendable {
    let status: String
    let vol: WireDecimal
    let volExec: WireDecimal
    let price: WireDecimal
    let opentm: Date
    let closetm: Date?

    private enum CodingKeys: String, CodingKey {
        case status, vol, price, opentm, closetm
        case volExec = "vol_exec"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
        self.vol = try container.decode(WireDecimal.self, forKey: .vol)
        self.volExec = try container.decode(WireDecimal.self, forKey: .volExec)
        self.price = try container.decode(WireDecimal.self, forKey: .price)
        self.opentm = try container.decode(KrakenSeconds.self, forKey: .opentm).date
        self.closetm = try container.decodeIfPresent(KrakenSeconds.self, forKey: .closetm)?.date
    }
}

struct KrakenOpenOrders: Decodable, Sendable {
    struct Order: Decodable, Sendable {
        struct Description: Decodable, Sendable {
            let pair: String
            let type: String
        }

        let descr: Description
        let vol: WireDecimal
        let volExec: WireDecimal

        private enum CodingKeys: String, CodingKey {
            case descr, vol
            case volExec = "vol_exec"
        }
    }

    let open: [String: Order]
}

struct KrakenCancelled: Decodable, Sendable {
    let count: Int
}

struct KrakenTradeBalance: Decodable, Sendable {
    let eb: WireDecimal
    let mf: WireDecimal
}

struct KrakenOpenPosition: Decodable, Sendable {
    let pair: String
    let type: String
    let cost: WireDecimal
    let vol: WireDecimal
    let volClosed: WireDecimal
    let value: WireDecimal

    private enum CodingKeys: String, CodingKey {
        case pair, type, cost, vol, value
        case volClosed = "vol_closed"
    }
}

struct KrakenTrades: Decodable, Sendable {
    struct Trade: Decodable, Sendable {
        let ordertxid: String
        let pair: String
        let time: WireDecimal
        let type: String
        let price: WireDecimal
        let fee: WireDecimal
        let vol: WireDecimal

        private enum CodingKeys: String, CodingKey {
            case ordertxid, pair, time, type, price, fee, vol
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.ordertxid = try container.decode(String.self, forKey: .ordertxid)
            self.pair = try container.decode(String.self, forKey: .pair)
            self.time = try container.decode(KrakenSeconds.self, forKey: .time).seconds
            self.type = try container.decode(String.self, forKey: .type)
            self.price = try container.decode(WireDecimal.self, forKey: .price)
            self.fee = try container.decode(WireDecimal.self, forKey: .fee)
            self.vol = try container.decode(WireDecimal.self, forKey: .vol)
        }
    }

    let trades: [String: Trade]
}

struct KrakenLedger: Decodable, Sendable {
    struct Entry: Decodable, Sendable {
        let time: WireDecimal
        let type: String
        let subtype: String
        let asset: String
        let amount: WireDecimal

        private enum CodingKeys: String, CodingKey {
            case time, type, subtype, asset, amount
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.time = try container.decode(KrakenSeconds.self, forKey: .time).seconds
            self.type = try container.decode(String.self, forKey: .type)
            self.subtype = try container.decodeIfPresent(String.self, forKey: .subtype) ?? ""
            self.asset = try container.decode(String.self, forKey: .asset)
            self.amount = try container.decode(WireDecimal.self, forKey: .amount)
        }
    }

    let ledger: [String: Entry]
}

// A time Kraken sends as a JSON number of seconds, "1688667796.8802". JSONDecoder reads a number as a Double, which
// carries Kraken's ten-thousandths exactly enough to be written back as the same text at four places.
struct KrakenSeconds: Decodable, Sendable {
    let seconds: WireDecimal

    var date: Date {
        Date(timeIntervalSince1970: Double(seconds.digits) / Double(WireDecimal.powerOfTen(seconds.fractionDigits)))
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) { // Kraken writes some times as text, most as numbers
            self.seconds = try WireDecimal(parsing: text)
        } else {
            let value = try container.decode(Double.self)
            self.seconds = WireDecimal(digits: Int128((value * 10_000).rounded()), fractionDigits: 4)
        }
    }
}

// The status page's upcoming maintenance (Atlassian Statuspage's shape, as Kraken publishes it).
struct KrakenStatusPage: Decodable, Sendable {
    struct Maintenance: Decodable, Sendable {
        let scheduledFor: String?
        let scheduledUntil: String?

        private enum CodingKeys: String, CodingKey {
            case scheduledFor = "scheduled_for"
            case scheduledUntil = "scheduled_until"
        }

        var start: Date? { scheduledFor.flatMap(Self.date) }
        var end: Date? { scheduledUntil.flatMap(Self.date) }

        private static func date(_ text: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: text)
        }
    }

    let scheduledMaintenances: [Maintenance]

    private enum CodingKeys: String, CodingKey {
        case scheduledMaintenances = "scheduled_maintenances"
    }
}
