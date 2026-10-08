// LocalizationFixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoAssetLocalization
import FOSFoundation
import FOSMVVM
import FOSTesting
import Foundation

// Values every suite shares. Instances come from the library's constants, never from an id written here.

enum LocalizationFixtures {
    static let enUS = Locale(identifier: "en_US")
    static let deDE = Locale(identifier: "de_DE")

    static let usd = ISO4217.usd.instance                   // decimals 2, the dollar's sign "$"
    static let btc = BIP122.Bitcoin.btc.instance            // decimals 8, the bitcoin's sign "₿", satoshi named
    static let eth = EIP155.Ethereum.eth.instance           // decimals 18, the ether's sign "Ξ"
    static let sol = SOLANA.Solana.sol.instance             // decimals 9, no unit named: its symbol

    static var satoshi: Asset.Unit {
        do {
            guard let unit = try AssetRegistry.shared.declaration(of: .btc).unit(named: "satoshi") else {
                preconditionFailure("The bitcoin's declaration names no satoshi")
            }
            return unit
        } catch {
            preconditionFailure("\(error)")
        }
    }

    static func whole(_ count: Int, _ instance: AssetInstance) -> Amount {
        do { return try Amount(whole: count, of: instance) } catch { preconditionFailure("\(error)") }
    }
}

/// The store FOSMVVM's localizing encoder needs, loaded as FOSMVVM's own tests load theirs
protocol LocalizationStoreSuite: LocalizableTestCase {}

extension LocalizationStoreSuite {
    var locales: Set<Locale> {
        [LocalizationFixtures.enUS, LocalizationFixtures.deDE]
    }

    static func testStore() throws -> LocalizationStore {
        try loadLocalizationStore(bundle: .module, resourceDirectoryName: "Resources")
    }

    func text(_ localizable: some Localizable, _ locale: Locale = LocalizationFixtures.enUS) throws -> String? {
        try localizable.localized(in: locale, store: locStore)
    }
}
