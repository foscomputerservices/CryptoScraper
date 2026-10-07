// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for the identity PR's re-projected suites (AR14's second channel, step 6), projected from
// the documents alone. Each maps one call a projected file writes onto the surface the code declares: wiring only,
// never a behavior. No assertion of a projected file is edited; a red that is not a defect is disabled in place with
// its classification as the reason.

import CryptoAsset
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import FOSFoundation
import FOSTestingVapor
import Foundation
import Testing
import Vapor

// MARK: D35 — the archived row through the two drivers

/// `StoredRowHarness`: the projected name for this target's two-driver harness (FOSTestingVapor's in-memory SQLite,
/// and an opt-in Postgres), one value stored whole in a JSON column and read back, as `TwoDriverEncodingTests` does
enum StoredRowHarness {
    struct NotATestDatabase: Error { let url: String }

    static func sqliteRoundTrip(_ amount: Amount) async throws -> Amount {
        try await sqlite(StoredValueRow(amount: amount)).amount!
    }

    static func sqliteRoundTrip(_ price: Price) async throws -> Price {
        try await sqlite(StoredValueRow(price: price)).price!
    }

    /// The projected opt-in's variable is `POSTGRES_URL`; as `TwoDriverEncodingTests` does, a database whose name
    /// does not end in `_test` is refused
    static func postgresRoundTrip(_ amount: Amount) async throws -> Amount {
        try await postgres(StoredValueRow(amount: amount)).amount!
    }

    private static func sqlite(_ row: StoredValueRow) async throws -> StoredValueRow {
        try await withFluentTestApp { app in
            app.migrations.add(CreateStoredValueRow())
        } _: { _, db in
            try await storeAndRead(row, on: db)
        }
    }

    private static func postgres(_ row: StoredValueRow) async throws -> StoredValueRow {
        let url = ProcessInfo.processInfo.environment["POSTGRES_URL"] ?? ""
        guard isTestDatabase(url) else { throw NotATestDatabase(url: url) }
        let app = try await Application.make(.testing)
        do {
            try app.databases.use(.postgres(url: url), as: .psql)
            app.migrations.add(CreateStoredValueRow())
            try await app.autoRevert()
            try await app.autoMigrate()
            let read = try await storeAndRead(row, on: app.db)
            try await app.autoRevert()
            try await app.asyncShutdown()
            return read
        } catch {
            await TwoDriverEncodingTests.cleanUp(app)
            throw error
        }
    }

    private static func storeAndRead(_ row: StoredValueRow, on db: any Database) async throws -> StoredValueRow {
        try await row.save(on: db)
        return try #require(try await StoredValueRow.query(on: db).first())
    }
}

/// A test-only model: one amount or one price, whole in one JSON column
final class StoredValueRow: Model, @unchecked Sendable {
    static let schema = "cryptoasset_behavioral_rows"

    @ID(key: .id) var id: UUID?
    @OptionalField(key: "amount") var amount: Amount?
    @OptionalField(key: "price") var price: Price?

    init() {}

    init(amount: Amount? = nil, price: Price? = nil) {
        self.amount = amount
        self.price = price
    }
}

struct CreateStoredValueRow: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(StoredValueRow.schema)
            .id()
            .field("amount", .json)
            .field("price", .json)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(StoredValueRow.schema).delete()
    }
}

// MARK: D27 — the generated namespaces' names

extension EIP155.Polygon {
    /// The projected `usdc`: the generated constant is named from CoinGecko's id, `usdCoin`, as Ethereum's alias is
    static var usdc: AssetDeclaration.Instance { usdCoin }
}

extension Assets {
    /// The projected `Assets.bitcoin`: the code declares Bitcoin's class by hand among the library's declarations,
    /// never generated, so this is that declaration
    static var bitcoin: AssetDeclaration {
        AssetRegistry.libraryDeclarations.first { $0.asset == .btc }!
    }
}

// MARK: D26 — BNB Smart Chain's USDC

extension EIP155 {
    /// The projected `BNBSmartChain`: the code's name for `eip155:56` is `BinanceSmartChain` (the 2023 chain's)
    typealias BNBSmartChain = BinanceSmartChain
}

extension EIP155.BinanceSmartChain {
    /// The projected `usdc` on BNB Smart Chain. NOT DECLARED: CoinGecko's `usd-coin` lists no `binance-smart-chain`
    /// contract (the recorded `coin-usd-coin.json`), so the importer generated none. This placeholder is an instance on
    /// the chain that no declaration lists, never a real contract; every test that reads it is classified in place.
    static var usdc: AssetDeclaration.Instance {
        try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "usdc-not-declared"), decimals: 6, symbol: AssetSymbol(validating: "USDC")
        )
    }
}
