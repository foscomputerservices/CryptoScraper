// D21 — One asset's declaration.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.1: "One declaration per asset, keyed by its
// class. It lists the asset's instances, on chains and on exchanges, each with its decimals and its symbol." And the
// owner's ruling of 2026-10-07: a chain that names no sub-unit counts in its base unit at exponent 0 ("default it to
// the chain's count").

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("D21 AssetDeclaration")
struct D21_AssetDeclarationTests {
    private let home = AssetInstance.stub()
    private let away = AssetInstance.stub(chainId: "bedrock:43", address: "quarry-42")

    private func instance(_ instance: AssetInstance, decimals: Int) throws -> AssetDeclaration.Instance {
        try AssetDeclaration.Instance(instance: instance, decimals: decimals, symbol: .stub())
    }

    // "0 through 30" — the edges are accepted
    @Test(arguments: [0, 30])
    func decimalsAtTheEdgesAreAccepted(_ decimals: Int) throws {
        #expect(try instance(home, decimals: decimals).decimals == decimals)
    }

    // "Throws ``AssetError/decimalsOutOfRange(_:)`` outside 0 through 30"
    @Test(arguments: [-1, 31])
    func decimalsOutsideTheRangeThrow(_ decimals: Int) {
        #expect(throws: AssetError.decimalsOutOfRange(decimals)) { try instance(home, decimals: decimals) }
    }

    // "Throws ``AssetError/noInstances``"
    @Test func noInstancesThrows() {
        #expect(throws: AssetError.noInstances) {
            try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(), instances: [])
        }
    }

    // "``AssetError/unitOutOfRange`` when a unit's exponent is not between 0 and the home instance's decimals"
    @Test func unitAboveTheHomesDecimalsThrows() throws {
        let gravel = Asset.Unit(name: "gravel", exponent: 9)
        #expect(throws: AssetError.unitOutOfRange(gravel)) {
            try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                 between: [gravel], instances: [instance(home, decimals: 8)])
        }
    }

    // "``AssetError/unitOutOfRange`` when a unit's exponent is not between 0 and the home instance's decimals" — below 0
    @Test func unitBelowZeroThrows() throws {
        let dust = Asset.Unit(name: "dust", exponent: -1)
        #expect(throws: AssetError.unitOutOfRange(dust)) {
            try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                 between: [dust], instances: [instance(home, decimals: 8)])
        }
    }

    // "The whole unit: its name, sign and fraction digits; the symbol stands in where none was given"
    @Test func wholeUnitDefaultsToTheSymbolAtTheHomesDecimals() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 8)])
        #expect(declaration.wholeUnit.name == AssetSymbol.stub().text)
        #expect(declaration.wholeUnit.exponent == 8)
    }

    // "The base unit, where the world names it" — none named, none declared
    @Test func baseUnitIsNilWhenNotNamed() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 8)])
        #expect(declaration.baseUnit == nil)
    }

    // owner, 2026-10-07: "a chain that names no sub-unit counts in its base unit at exponent 0"
    @Test func unnamedBaseUnitCountsAtExponentZero() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 8)])
        let registry = try AssetRegistry([declaration])
        let one = Amount(baseUnits: 1, of: home)
        let read = try one.count(in: declaration.wholeUnit, in: registry)
        #expect(read.count == 0)
        #expect(read.remainder == 1)
    }

    // "The base unit, where the world names it: satoshi, wei, cent" — a named base unit sits at exponent 0
    @Test func namedBaseUnitIsAtExponentZero() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               baseUnit: .init(name: "pebble"),
                                               instances: [instance(home, decimals: 4)])
        #expect(declaration.baseUnit?.exponent == 0)
        #expect(declaration.baseUnit?.name == "pebble")
    }

    // "The unit a reader sees by default" — the whole unit unless the declaration says otherwise (C2)
    @Test func displayUnitDefaultsToTheWholeUnit() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 4)])
        #expect(declaration.displayUnit == declaration.wholeUnit)
    }

    // "Every unit a reader may count in, at the home instance's decimals" — base, between, whole (C2's order)
    @Test func unitsListBaseBetweenWhole() throws {
        let mid = Asset.Unit(name: "rubble", exponent: 2)
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               wholeUnit: .init(name: "boulder"), baseUnit: .init(name: "pebble"),
                                               between: [mid], instances: [instance(home, decimals: 4)])
        #expect(declaration.units.map(\.name) == ["pebble", "rubble", "boulder"])
        #expect(declaration.units.map(\.exponent) == [0, 2, 4])
    }

    // "public func unit(named name: String) -> Asset.Unit?"
    @Test func unitNamedFindsOrReturnsNil() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               wholeUnit: .init(name: "boulder"), baseUnit: .init(name: "pebble"),
                                               instances: [instance(home, decimals: 4)])
        #expect(declaration.unit(named: "pebble")?.exponent == 0)
        #expect(declaration.unit(named: "boulder")?.exponent == 4)
        #expect(declaration.unit(named: "gravel") == nil)
    }

    // "Every instance of the asset, its home first"
    @Test func instancesKeepTheirOrderHomeFirst() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 6), instance(away, decimals: 8)])
        #expect(declaration.instances.map(\.instance) == [home, away])
    }

    // "each with its decimals and its symbol" — two instances of one asset keep their own decimals
    @Test func eachInstanceKeepsItsOwnDecimals() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 6), instance(away, decimals: 8)])
        #expect(declaration.instances.map(\.decimals) == [6, 8])
    }

    // "Three fields are your `TokenInfo`'s, by its names."
    @Test func tokenInfoFieldsAreKept() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               aggregatorId: "fred-coin", instances: [instance(home, decimals: 4)])
        #expect(declaration.tokenName == "Fred Coin")
        #expect(declaration.symbol == .stub())
        #expect(declaration.aggregatorId == "fred-coin")
    }

    // "Codable" — the declaration round-trips
    @Test func declarationRoundTrips() throws {
        let declaration = try AssetDeclaration(asset: .stub(home: home), tokenName: "Fred Coin", symbol: .stub(),
                                               instances: [instance(home, decimals: 6), instance(away, decimals: 8)])
        let back: AssetDeclaration = try declaration.toJSON().fromJSON()
        #expect(back == declaration)
    }
}
