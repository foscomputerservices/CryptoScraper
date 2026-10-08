// AddressCaseTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

// An EIP-155 address's case is a display checksum (EIP-55), never part of the identity: the validator stores the
// lowercase form. Every other namespace keeps its address exactly as given. Every id here is taken from a generated
// constant and re-spelled; none is typed.

@Suite("Address case")
struct AddressCaseTests {
    /// `id` with its address part after "0x" in capitals, the spelling a checksummed source hands up
    private static func checksummedSpelling(of id: String) -> String {
        let lastColon = id.lastIndex(of: ":")!
        let head = id[...lastColon]
        let address = id[id.index(after: lastColon)...]
        return head + "0x" + address.dropFirst(2).uppercased()
    }

    private static let canonical = EIP155.Ethereum.aave.instance.id
    private static let checksummed = checksummedSpelling(of: canonical)

    @Test func aChecksummedEIP155AddressValidatesToTheLowercaseId() throws {
        #expect(Self.checksummed != Self.canonical)
        let instance = try AssetInstance(validating: Self.checksummed)
        #expect(instance.id == Self.canonical)
        #expect(instance.address == EIP155.Ethereum.aave.instance.address)
    }

    @Test func theTwoSpellingsAreEqualAndHashEqual() throws {
        let given = try AssetInstance(validating: Self.checksummed)
        let lower = try AssetInstance(validating: Self.canonical)
        #expect(given == lower)
        #expect(given.hashValue == lower.hashValue)
        #expect(Set([given, lower]).count == 1)
    }

    @Test func aSolanaAddressKeepsItsCaseExactly() throws {
        let id = SOLANA.Solana.aave.instance.id
        #expect(id != id.lowercased())
        #expect(try AssetInstance(validating: id).id == id)
        let respelled = id.lowercased()
        #expect(try AssetInstance(validating: respelled).id == respelled)
        #expect(try AssetInstance(validating: respelled) != AssetInstance(validating: id))
    }

    @Test func aTronAddressKeepsItsCaseExactly() throws {
        let id = TRON.Tron.tether.instance.id
        #expect(id != id.lowercased())
        #expect(try AssetInstance(validating: id).id == id)
        let respelled = id.lowercased()
        #expect(try AssetInstance(validating: respelled).id == respelled)
        #expect(try AssetInstance(validating: respelled) != AssetInstance(validating: id))
    }

    @Test func aBitcoinAddressKeepsItsCaseExactly() throws {
        let id = BIP122.Bitcoin.btc.instance.id
        let lastColon = id.lastIndex(of: ":")!
        let respelled = String(id[...lastColon]) + id[id.index(after: lastColon)...].uppercased()
        #expect(respelled != id)
        #expect(try AssetInstance(validating: respelled).id == respelled)
        #expect(try AssetInstance(validating: respelled) != AssetInstance(validating: id))
    }

    @Test func anAssetWithAChecksummedHomeIdEqualsTheLibrarysClass() throws {
        let given = try Asset(validating: Self.checksummed)
        #expect(given.id == Self.canonical)
        #expect(given == (try AssetRegistry.shared.asset(of: EIP155.Ethereum.aave.instance)))
        #expect(given == Assets.aave.asset)
    }

    @Test func decodingAChecksummedIdYieldsTheCanonicalInstanceAndEncodingGivesTheCanonicalId() throws {
        let json = Data("\"\(Self.checksummed)\"".utf8)
        let decoded = try JSONDecoder().decode(AssetInstance.self, from: json)
        #expect(decoded.id == Self.canonical)
        #expect(decoded == EIP155.Ethereum.aave.instance)
        let encoded = try JSONEncoder().encode(decoded)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"\(Self.canonical)\"")

        let asset = try JSONDecoder().decode(Asset.self, from: json)
        #expect(asset.id == Self.canonical)
    }

    @Test func theRegistryResolvesAChecksummedInstanceToTheSameClass() throws {
        let given = try AssetInstance(validating: Self.checksummed)
        let lower = try AssetInstance(validating: Self.canonical)
        let registry = AssetRegistry.shared
        #expect(try registry.asset(of: given) == registry.asset(of: lower))
        #expect(try registry.asset(of: given) == Assets.aave.asset)
    }

    @Test func aMalformedIdStillThrowsWithTheIdAsGiven() {
        let malformed = EIP155.Ethereum.chainId + ":"
        #expect(throws: AssetError.malformedIdentity(malformed)) {
            try AssetInstance(validating: malformed)
        }
        let shapeless = "0X" + Self.checksummed
        #expect(throws: AssetError.malformedIdentity(shapeless)) {
            try AssetInstance(validating: shapeless)
        }
        #expect(throws: AssetError.malformedIdentity(shapeless)) {
            try Asset(validating: shapeless)
        }
    }
}
