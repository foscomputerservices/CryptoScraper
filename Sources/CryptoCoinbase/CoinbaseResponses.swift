// CoinbaseResponses.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import Foundation

// The parts of Coinbase Advanced Trade's answers the client reads, shaped as its JSON. Every number Coinbase sends
// as text is decoded here into an exact WireDecimal.

struct CoinbaseProducts: Decodable, Sendable {
    let products: [CoinbaseProduct]
}

struct CoinbaseProduct: Decodable, Sendable {
    let productId: String
    let baseCurrencyId: String
    let quoteCurrencyId: String
    let baseIncrement: WireDecimal
    let quoteIncrement: WireDecimal
    let baseMinSize: WireDecimal
    let volume24h: WireDecimal?
    let quoteVolume24h: WireDecimal?
    let status: String
    let restriction: String?
    let isPerpetual: Bool
    let maxLeverage: Int?
    let rootUnit: String?

    private enum CodingKeys: String, CodingKey {
        case productId = "product_id", baseCurrencyId = "base_currency_id", quoteCurrencyId = "quote_currency_id"
        case baseIncrement = "base_increment", quoteIncrement = "quote_increment", baseMinSize = "base_min_size"
        case volume24h = "volume_24h", quoteVolume24h = "approximate_quote_24h_volume", status
        case tradingDisabled = "trading_disabled", isDisabled = "is_disabled", cancelOnly = "cancel_only", limitOnly = "limit_only", postOnly = "post_only"
        case futureProductDetails = "future_product_details"
    }

    private struct Future: Decodable {
        struct Perpetual: Decodable {
            let maxLeverage: String?
            private enum CodingKeys: String, CodingKey { case maxLeverage = "max_leverage" }
        }

        let contractExpiryType: String?
        let contractRootUnit: String?
        let perpetualDetails: Perpetual?

        private enum CodingKeys: String, CodingKey {
            case contractExpiryType = "contract_expiry_type", contractRootUnit = "contract_root_unit", perpetualDetails = "perpetual_details"
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.productId = try container.decode(String.self, forKey: .productId)
        self.baseCurrencyId = try container.decode(String.self, forKey: .baseCurrencyId)
        self.quoteCurrencyId = try container.decode(String.self, forKey: .quoteCurrencyId)
        self.baseIncrement = try container.decode(WireDecimal.self, forKey: .baseIncrement)
        self.quoteIncrement = try container.decode(WireDecimal.self, forKey: .quoteIncrement)
        self.baseMinSize = try container.decode(WireDecimal.self, forKey: .baseMinSize)
        // Coinbase writes an unknown day's volume as "", which is no number and no zero.
        let volumeText = try container.decodeIfPresent(String.self, forKey: .volume24h) ?? ""
        self.volume24h = volumeText.isEmpty ? nil : try WireDecimal(parsing: volumeText)
        let turnoverText = try container.decodeIfPresent(String.self, forKey: .quoteVolume24h) ?? ""
        self.quoteVolume24h = turnoverText.isEmpty ? nil : try WireDecimal(parsing: turnoverText)
        self.status = try container.decode(String.self, forKey: .status)
        let flags: [(CodingKeys, String)] = [(.tradingDisabled, "trading_disabled"), (.isDisabled, "is_disabled"), (.cancelOnly, "cancel_only"),
                                             (.limitOnly, "limit_only"), (.postOnly, "post_only")]
        self.restriction = try flags.first { try container.decodeIfPresent(Bool.self, forKey: $0.0) == true }?.1
        let future = try container.decodeIfPresent(Future.self, forKey: .futureProductDetails)
        self.isPerpetual = future?.contractExpiryType == "PERPETUAL"
        self.maxLeverage = future?.perpetualDetails?.maxLeverage.flatMap { Int($0) }
        self.rootUnit = future?.contractRootUnit
    }

    // The product's two holdings through the table, each increment's places checked against the declared holding's
    // decimals (AR45); a product with an empty base currency id names its base by its contract's root unit. A currency the table lacks, or a holding the
    // statement does not declare, is nil.
    func holdings(in registry: AssetRegistry) throws -> CoinbasePair {
        let base = baseCurrencyId.isEmpty ? (rootUnit ?? baseCurrencyId) : baseCurrencyId
        return CoinbasePair(
            base: try CoinbaseExchangeChain.declaredInstance(wireName: base, decimals: baseIncrement.fractionDigits, in: registry),
            quote: try CoinbaseExchangeChain.declaredInstance(wireName: quoteCurrencyId, decimals: quoteIncrement.fractionDigits, in: registry),
            baseName: base, quoteName: quoteCurrencyId
        )
    }
}

// A product's two declared holdings, nil where undeclared, and Coinbase's names for them.
struct CoinbasePair: Sendable {
    let base: AssetInstance?
    let quote: AssetInstance?
    let baseName: String
    let quoteName: String

    // A pair both of whose holdings are declared: the only kind a money value is made in.
    struct Declared: Sendable {
        let base: AssetInstance
        let quote: AssetInstance
    }

    func declared() throws -> Declared {
        guard let base else { throw ExchangeClientError.unknownAsset(baseName) }
        guard let quote else { throw ExchangeClientError.unknownAsset(quoteName) }
        return Declared(base: base, quote: quote)
    }
}

struct CoinbaseProductBook: Decodable, Sendable {
    struct Level: Decodable, Sendable {
        let price: WireDecimal
    }

    struct Book: Decodable, Sendable {
        let bids: [Level]
        let asks: [Level]
        let time: String
    }

    let pricebook: Book
    let midMarket: WireDecimal

    private enum CodingKeys: String, CodingKey {
        case pricebook, midMarket = "mid_market"
    }
}

struct CoinbaseCreatedOrder: Decodable, Sendable {
    struct Success: Decodable, Sendable {
        let orderId: String
        private enum CodingKeys: String, CodingKey { case orderId = "order_id" }
    }

    struct Failure: Decodable, Sendable {
        let error: String
        let message: String
    }

    let success: Bool
    let successResponse: Success?
    let errorResponse: Failure?

    private enum CodingKeys: String, CodingKey {
        case success, successResponse = "success_response", errorResponse = "error_response"
    }
}

struct CoinbaseOrder: Decodable, Sendable {
    let orderId: String
    let productId: String
    let side: String
    let status: String
    let filledSize: WireDecimal
    let averageFilledPrice: WireDecimal
    let lastFillTime: String?
    let rejectMessage: String?
    let baseSize: WireDecimal?
    /// The client order id the order was created with, as Coinbase hands it back
    let clientOrderId: String?

    private enum CodingKeys: String, CodingKey {
        case orderId = "order_id", productId = "product_id", side, status, filledSize = "filled_size", clientOrderId = "client_order_id"
        case averageFilledPrice = "average_filled_price", lastFillTime = "last_fill_time", rejectMessage = "reject_message"
        case orderConfiguration = "order_configuration"
    }

    private struct Sized: Decodable {
        let baseSize: WireDecimal?
        private enum CodingKeys: String, CodingKey { case baseSize = "base_size" }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderId = try container.decode(String.self, forKey: .orderId)
        self.productId = try container.decode(String.self, forKey: .productId)
        self.side = try container.decode(String.self, forKey: .side)
        self.status = try container.decode(String.self, forKey: .status)
        self.filledSize = try container.decode(WireDecimal.self, forKey: .filledSize)
        self.averageFilledPrice = try container.decode(WireDecimal.self, forKey: .averageFilledPrice)
        self.lastFillTime = try container.decodeIfPresent(String.self, forKey: .lastFillTime)
        self.rejectMessage = try container.decodeIfPresent(String.self, forKey: .rejectMessage)
        self.clientOrderId = try container.decodeIfPresent(String.self, forKey: .clientOrderId)
        // The order's configuration is one entry, keyed by the kind of order; its base size is the order's size.
        let configurations = try container.decodeIfPresent([String: Sized].self, forKey: .orderConfiguration) ?? [:]
        self.baseSize = configurations.values.compactMap(\.baseSize).first
    }
}

struct CoinbaseOrderEnvelope: Decodable, Sendable {
    let order: CoinbaseOrder
}

struct CoinbaseOrders: Decodable, Sendable {
    let orders: [CoinbaseOrder]
}

struct CoinbaseCancelResults: Decodable, Sendable {
    struct Result: Decodable, Sendable {
        let success: Bool
        let failureReason: String?
        private enum CodingKeys: String, CodingKey { case success, failureReason = "failure_reason" }
    }

    let results: [Result]
}

struct CoinbaseAccount: Decodable, Sendable {
    struct Balance: Decodable, Sendable {
        let value: WireDecimal
    }

    let currency: String
    let availableBalance: Balance
    let hold: Balance?

    private enum CodingKeys: String, CodingKey {
        case currency, availableBalance = "available_balance", hold
    }
}

struct CoinbaseAccounts: Decodable, Sendable {
    let accounts: [CoinbaseAccount]
    let hasNext: Bool
    let cursor: String?

    private enum CodingKeys: String, CodingKey {
        case accounts, hasNext = "has_next", cursor
    }
}

struct CoinbaseKeyPermissions: Decodable, Sendable {
    let canTrade: Bool
    let canTransfer: Bool
    /// The uuid of the portfolio the key belongs to, the one its account reads answer for
    let portfolioUuid: String
    let portfolioType: String

    private enum CodingKeys: String, CodingKey {
        case canTrade = "can_trade", canTransfer = "can_transfer", portfolioUuid = "portfolio_uuid", portfolioType = "portfolio_type"
    }
}

struct CoinbaseFill: Decodable, Sendable {
    let orderId: String
    let tradeTime: String
    let price: WireDecimal
    let size: WireDecimal
    let commission: WireDecimal
    let productId: String
    let sequenceTimestamp: String
    let side: String

    private enum CodingKeys: String, CodingKey {
        case orderId = "order_id", tradeTime = "trade_time", price, size, commission, productId = "product_id"
        case sequenceTimestamp = "sequence_timestamp", side
    }
}

struct CoinbaseFills: Decodable, Sendable {
    let fills: [CoinbaseFill]
    let cursor: String?
}

struct CoinbaseMovedFunds: Decodable, Sendable {
    let sourcePortfolioUuid: String

    private enum CodingKeys: String, CodingKey {
        case sourcePortfolioUuid = "source_portfolio_uuid"
    }
}

// The status page's upcoming maintenance (Atlassian Statuspage's shape, as Coinbase publishes it).
struct CoinbaseStatusPage: Decodable, Sendable {
    struct Maintenance: Decodable, Sendable {
        struct Component: Decodable, Sendable { let name: String }
        struct Update: Decodable, Sendable {
            let affectedComponents: [Component]?
            private enum CodingKeys: String, CodingKey { case affectedComponents = "affected_components" }
        }

        let name: String?
        let scheduledFor: String?
        let scheduledUntil: String?
        let components: [Component]?
        let incidentUpdates: [Update]?

        private enum CodingKeys: String, CodingKey {
            case name, components
            case scheduledFor = "scheduled_for", scheduledUntil = "scheduled_until"
            case incidentUpdates = "incident_updates"
        }

        /// Coinbase's own words, from the maintenance's name and every component it lists: trading wins over transfers,
        /// a window naming neither is `.other`
        ///   trading: "trading", "trade", "order", "matching engine", "exchange"
        ///   transfers: "withdraw", "deposit", "send", "receive", "transfer", "payment method"
        var subject: ExchangeClientMaintenanceWindow.Subject {
            let listed = (components ?? []).map(\.name) + (incidentUpdates ?? []).flatMap { ($0.affectedComponents ?? []).map(\.name) }
            let text = ([name ?? ""] + listed).joined(separator: " | ").lowercased()
            if ["trading", "trade", "order", "matching engine", "exchange"].contains(where: text.contains) { return .trading }
            if ["withdraw", "deposit", "send", "receive", "transfer", "payment method"].contains(where: text.contains) { return .transfers }
            return .other
        }
    }

    let scheduledMaintenances: [Maintenance]

    private enum CodingKeys: String, CodingKey {
        case scheduledMaintenances = "scheduled_maintenances"
    }
}
