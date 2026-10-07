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
// Postgres runs only when CRYPTOASSET_POSTGRES_URL is set AND the URL's database name ends in `_test`, e.g.
//   createdb cryptoasset_test
//   CRYPTOASSET_POSTGRES_URL=postgres://david@localhost:5432/cryptoasset_test swift test --filter TwoDriver
// The test reverts, migrates and writes to the database the URL names, so it refuses any other name: a URL that
// points at a shared or production database skips the test instead of touching it. It creates its own table,
// `cryptoasset_encoding_test_rows`, a name no production schema has, and drops it again; a failed drop is
// recorded as an issue, never swallowed.

private let postgresURL = ProcessInfo.processInfo.environment["CRYPTOASSET_POSTGRES_URL"]

// The database name of a Postgres URL: the last path component, before any query or fragment.
func postgresDatabaseName(of url: String) -> String? {
    guard let components = URLComponents(string: url) else { return nil }
    let name = components.path.split(separator: "/").last.map(String.init)
    return name?.isEmpty == false ? name : nil
}

func isTestDatabase(_ url: String) -> Bool {
    postgresDatabaseName(of: url)?.hasSuffix("_test") == true
}

private let postgresTestEnabled = postgresURL.map(isTestDatabase) ?? false

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

    @Test func onlyADatabaseNamedForTestingIsAccepted() {
        #expect(isTestDatabase("postgres://david@localhost:5432/cryptoasset_test"))
        #expect(isTestDatabase("postgres://david:pw@db.example.com/fosline_test?sslmode=require"))
        #expect(!isTestDatabase("postgres://david@localhost:5432/postgres"))
        #expect(!isTestDatabase("postgres://david@localhost:5432/cryptoasset_test_backup"))
        #expect(!isTestDatabase("postgres://david@localhost:5432/test"))
        #expect(!isTestDatabase("postgres://david@localhost:5432/"))
        #expect(!isTestDatabase("postgres://david@localhost:5432"))
        #expect(!isTestDatabase("not a url"))
    }

    @Test(.enabled(if: postgresTestEnabled,
                   "set CRYPTOASSET_POSTGRES_URL to a Postgres whose database name ends in _test (createdb cryptoasset_test); any other name is refused"))
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
            await Self.cleanUp(app)
            throw error
        }
    }

    // The error that brought the test here propagates; a failure of its cleanup is recorded beside it.
    static func cleanUp(_ app: Application) async {
        do {
            try await app.autoRevert()
        } catch {
            Issue.record("cleanup could not drop \(EncodingRow.schema): \(error)")
        }
        do {
            try await app.asyncShutdown()
        } catch {
            Issue.record("cleanup could not shut the application down: \(error)")
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
                amount: Amount(baseUnits: n, of: Fixtures.eth),
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
            #expect(r.amount.instance == w.amount.instance)
            #expect(r.price.quote == w.price.quote)
            #expect(r.price.base == w.price.base)
            #expect(r.price.scaled == w.price.scaled)
        }
    }
}

// A minimal test-only model: each value whole in one JSON column, as fosline's data models store them.
final class EncodingRow: Model, @unchecked Sendable {
    static let schema = "cryptoasset_encoding_test_rows"

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
