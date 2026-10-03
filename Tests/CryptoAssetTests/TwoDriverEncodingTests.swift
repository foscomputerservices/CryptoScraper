// TwoDriverEncodingTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import FOSFoundation
import FOSTestingVapor
import Foundation
import Testing
import Vapor

// R5 on both drivers: an Amount, a Fraction and a Price stored whole as JSON columns and read back by
// `JSONDecoder`, through FOSTestingVapor's in-memory SQLite harness and, opt-in, a local Postgres.
//
// Postgres runs only when CRYPTOASSET_POSTGRES_URL is set, e.g.
//   CRYPTOASSET_POSTGRES_URL=postgres://david@localhost:5432/postgres swift test --filter TwoDriver
// The test creates its own table and drops it again.

private let postgresURL = ProcessInfo.processInfo.environment["CRYPTOASSET_POSTGRES_URL"]

@Suite("Encoding on both drivers", .serialized)
struct TwoDriverEncodingTests {
    @Test func sqliteStoresAndReadsBackEqual() async throws {
        let rows = Self.rows()
        let read = try await withFluentTestApp { app in
            app.migrations.add(CreateEncodingRow())
        } _: { _, db in
            try await Self.storeAndRead(rows, on: db)
        }
        Self.expectEqual(read, rows)
    }

    @Test(.enabled(if: postgresURL != nil, "set CRYPTOASSET_POSTGRES_URL to run against a local Postgres"))
    func postgresStoresAndReadsBackEqual() async throws {
        let rows = Self.rows()
        let app = try await Application.make(.testing)
        do {
            try app.databases.use(.postgres(url: postgresURL!), as: .psql)
            app.migrations.add(CreateEncodingRow())
            try await app.autoRevert()
            try await app.autoMigrate()
            let read = try await Self.storeAndRead(rows, on: app.db)
            try await app.autoRevert()
            try await app.asyncShutdown()
            Self.expectEqual(read, rows)
        } catch {
            try? await app.autoRevert()
            try? await app.asyncShutdown()
            throw error
        }
    }

    // MARK: The three values at the extremes

    struct Values: Sendable, Equatable {
        let amount: Amount
        let fraction: Fraction
        let price: Price
    }

    static func rows() -> [Values] {
        Fixtures.extremes.map { n in
            Values(
                amount: Amount(baseUnits: n, asset: .eth),
                fraction: Fixtures.fraction(atScaled: n),
                price: Fixtures.price(atScaled: n)
            )
        }
    }

    static func storeAndRead(_ rows: [Values], on db: any Database) async throws -> [Values] {
        for (index, values) in rows.enumerated() {
            let row = EncodingRow()
            row.position = index
            row.amount = values.amount
            row.fraction = values.fraction
            row.price = values.price
            try await row.save(on: db)
        }
        return try await EncodingRow.query(on: db).sort(\.$position).all().map {
            Values(amount: $0.amount, fraction: $0.fraction, price: $0.price)
        }
    }

    static func expectEqual(_ read: [Values], _ written: [Values]) {
        #expect(read == written)
        for (r, w) in zip(read, written) {
            #expect(r.amount.baseUnits == w.amount.baseUnits)
            #expect(r.amount.asset.units == w.amount.asset.units)
            #expect(r.amount.asset.displayUnit == w.amount.asset.displayUnit)
            #expect(r.price.quote.units == w.price.quote.units)
            #expect(r.price.base.units == w.price.base.units)
        }
    }
}

// A minimal test-only model: each value whole in one JSON column, as fosline's data models store them.
final class EncodingRow: Model, @unchecked Sendable {
    static let schema = "crypto_asset_encoding_rows"

    @ID(key: .id) var id: UUID?
    @Field(key: "position") var position: Int
    @Field(key: "amount") var amount: Amount
    @Field(key: "fraction") var fraction: Fraction
    @Field(key: "price") var price: Price

    init() {}
}

struct CreateEncodingRow: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EncodingRow.schema)
            .id()
            .field("position", .int, .required)
            .field("amount", .json, .required)
            .field("fraction", .json, .required)
            .field("price", .json, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(EncodingRow.schema).delete()
    }
}
