// Fixtures.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

// Values every suite shares, each built through the public path only.

enum Fixtures {
    static let satoshi = Asset.btc.unit(named: "satoshi")!
    static let bitcoin = Asset.btc.unit(named: "bitcoin")!
    static let wei = Asset.eth.unit(named: "wei")!
    static let gwei = Asset.Unit(name: "gwei", exponent: 9)
    static let ether = Asset.eth.unit(named: "ether")!
    static let cent = Asset.usd.unit(named: "cent")!
    static let dollar = Asset.usd.unit(named: "dollar")!

    // A whole-unit token, as SNEK is: no base unit below the whole.
    static let snek = try! Asset(symbol: "SNEK", unitExponent: 0)

    // An 18-exponent cheap token, the last row of the headroom table.
    static let cheap = try! Asset(symbol: "CHEAP", unitExponent: 18)

    // An asset at exponent 0 so a price's scaled quote equals the quote's base units times the scale over the size.
    static let flat = try! Asset(symbol: "FLAT", unitExponent: 0)

    static let tenToThe30: Int128 = 1_000_000_000_000_000_000_000_000_000_000
    static let tenToThe9: Int128 = 1_000_000_000

    static let extremes: [Int128] = [.max, .min, tenToThe30]

    // A Fraction whose scaled numerator is exactly `numerator`, made through the public path:
    // numerator over 10^9 base units of one asset.
    static func fraction(atScaled numerator: Int128) -> Fraction {
        Fraction(Amount(baseUnits: numerator, asset: .usd), over: Amount(baseUnits: tenToThe9, asset: .usd))
    }

    // A Price whose scaled quote is exactly `numerator` USD base units: numerator for 10^9 of an exponent-0 asset.
    static func price(atScaled numerator: Int128) -> Price {
        Price(Amount(baseUnits: numerator, asset: .usd), per: Amount(baseUnits: tenToThe9, asset: flat))
    }
}
