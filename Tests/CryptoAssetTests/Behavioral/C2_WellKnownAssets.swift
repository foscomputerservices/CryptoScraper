// C2_WellKnownAssets.swift
//
// C2: the well-known assets ship as constants, each with its unit names (OQ-C5): Asset.usd, .usdc, .usdt,
// .btc, .eth — "cent and dollar, satoshi and bitcoin, wei, gwei and ether are declared once".
// The exponents asserted are the ones C2's DocC example declares for each.

import CryptoAsset
import FOSFoundation
import Foundation
import Testing

@Suite("Asset constants — C2 behavioral")
struct C2_WellKnownAssetsTests {

    // C2: Asset.usd — symbol USD, exponent 2, dollar and cent
    @Test func usdIsTwoPlacesWithDollarAndCent() throws {
        let usd = Asset.usd
        #expect(usd.symbol.text == "USD")
        #expect(usd.unitExponent == 2)
        #expect(usd.wholeUnit.name == "dollar")
        #expect(usd.wholeUnit.exponent == 2)
        let cent = try #require(usd.baseUnit)
        #expect(cent.name == "cent")
        #expect(cent.exponent == 0)
    }

    // C2: Asset.btc — symbol BTC, exponent 8, bitcoin and satoshi
    @Test func btcIsEightPlacesWithBitcoinAndSatoshi() throws {
        let btc = Asset.btc
        #expect(btc.symbol.text == "BTC")
        #expect(btc.unitExponent == 8)
        #expect(btc.wholeUnit.name == "bitcoin")
        let satoshi = try #require(btc.baseUnit)
        #expect(satoshi.name == "satoshi")
        #expect(satoshi.exponent == 0)
    }

    // C2: Asset.eth — symbol ETH, exponent 18, ether, gwei at 9, wei
    @Test func ethIsEighteenPlacesWithEtherGweiAndWei() throws {
        let eth = Asset.eth
        #expect(eth.symbol.text == "ETH")
        #expect(eth.unitExponent == 18)
        #expect(eth.wholeUnit.name == "ether")
        #expect(eth.wholeUnit.exponent == 18)
        let wei = try #require(eth.baseUnit)
        #expect(wei.name == "wei")
        #expect(wei.exponent == 0)
        let gwei = try #require(eth.unit(named: "gwei"))
        #expect(gwei.exponent == 9)
    }

    // C2: Asset.usdc — symbol USDC, exponent 6, "the base unit has no name"
    @Test func usdcIsSixPlacesWithAnUnnamedBaseUnit() {
        let usdc = Asset.usdc
        #expect(usdc.symbol.text == "USDC")
        #expect(usdc.unitExponent == 6)
        #expect(usdc.baseUnit == nil)
    }

    // C2: Asset.usdt — symbol USDT
    // Gap: no requirement or declaration states USDT's exponent or unit names; only the symbol is asserted.
    @Test func usdtIsNamedUSDT() {
        #expect(Asset.usdt.symbol.text == "USDT")
    }

    // C2: the five constants are five different assets
    @Test func theConstantsAreDistinctAssets() {
        let all: Set<Asset> = [.usd, .usdc, .usdt, .btc, .eth]
        #expect(all.count == 5)
    }

    // C2: USDC decoded without names and USDC declared with names are one asset, and their amounts add
    @Test func usdcWithoutNamesIsTheConstant() throws {
        let bare = try Asset(symbol: "USDC", unitExponent: 6)
        #expect(bare == Asset.usdc)
        let sum = Amount(baseUnits: 42, asset: bare) + Amount(baseUnits: 42, asset: .usdc)
        #expect(sum.baseUnits == 84)
    }
}

@Suite("DocC vectors — C2, C3, C4, C5 behavioral")
struct DocCVectorTests {

    // C2 / C3: `let stake = Amount(whole: 100, of: .usdc)` is 100 USDC, exactly
    @Test func oneHundredUSDCIsOneHundredMillionBaseUnits() {
        let stake = Amount(whole: 100, of: .usdc)
        #expect(stake.baseUnits == 100_000_000)
        #expect(stake.asset == .usdc)
    }

    // C3: `Amount(baseUnits: 2_500, asset: usdc)` is 0.0025 USDC, and `stake - fee` is exact
    @Test func stakeLessFeeIsExact() {
        let stake = Amount(whole: 100, of: .usdc)
        let fee = Amount(baseUnits: 2_500, asset: .usdc)
        #expect((stake - fee).baseUnits == 99_997_500)
    }

    // C3: `try Amount(count: 5, in: gwei, of: eth)` is 5 gwei exactly, and reads back as (5, 0)
    @Test func fiveGweiConvertsBothWays() throws {
        let gwei = try #require(Asset.eth.unit(named: "gwei"))
        let tip = try Amount(count: 5, in: gwei, of: .eth)
        #expect(tip.baseUnits == 5_000_000_000)
        let reading = tip.count(in: gwei)
        #expect(reading.count == 5)
        #expect(reading.remainder == 0)
    }

    // C3: `stake * Fraction(percent: 50)` is half
    @Test func halfOfTheStakeIsFiftyUSDC() {
        let stake = Amount(whole: 100, of: .usdc)
        #expect(stake * Fraction(percent: 50) == Amount(whole: 50, of: .usdc))
    }

    // C3: `notional / Fraction(integer: 2)` is half
    @Test func notionalOverTwoIsHalf() {
        let notional = Amount(whole: 100, of: .usdc)
        #expect(notional / Fraction(integer: 2) == Amount(whole: 50, of: .usdc))
    }

    // C5: $65,000 per BTC applied to 0.15 BTC costs $9,750.00 exactly, in usd
    @Test func midTimesSizeIsNineThousandSevenHundredFiftyDollars() {
        let mid = Price(Amount(whole: 65_000, of: .usd), per: .btc)
        let size = Amount(baseUnits: 15_000_000, asset: .btc)
        let cost = mid.cost(of: size)
        #expect(cost == Amount(whole: 9_750, of: .usd))
        #expect(cost.asset == .usd)
    }

    // C5: one step up the ladder of 5 basis points is $65,032.50 per BTC
    @Test func oneStepUpTheLadderIsFiveBasisPointsHigher() {
        let mid = Price(Amount(whole: 65_000, of: .usd), per: .btc)
        let ask = mid * (.one + Fraction(basisPoints: 5))
        #expect(ask.cost(of: Amount(whole: 1, of: .btc)) == Amount(baseUnits: 6_503_250, asset: .usd))
        #expect(mid < ask)
    }

    // C4: a long's stop level `entry * (.one - distance)` with a 2 % distance
    @Test func aLongsStopLevelIsTwoPercentBelowTheEntry() {
        let entry = Price(Amount(whole: 65_000, of: .usd), per: .btc)
        let level = entry * (.one - Fraction(percent: 2))
        #expect(level.cost(of: Amount(whole: 1, of: .btc)) == Amount(whole: 63_700, of: .usd))
    }

    // C5: 4,000 satoshis for 10,000 of a token is 0.4 satoshi each, exact (a sub-unit price)
    @Test func fourThousandSatoshisForTenThousandTokensIsExact() throws {
        let token = try Asset(symbol: "DINO", unitExponent: 0)
        let fill = Price(Amount(baseUnits: 4_000, asset: .btc), per: Amount(whole: 10_000, of: token))
        #expect(fill.isZero == false)
        #expect(fill.cost(of: Amount(whole: 10_000, of: token)) == Amount(baseUnits: 4_000, asset: .btc))
        #expect(fill.cost(of: Amount(whole: 5, of: token)) == Amount(baseUnits: 2, asset: .btc))
    }

    // C4: the gain in percent of the amount in: (out - in) over in
    @Test func theGainIsAFractionOfTheAmountIn() {
        let amountIn = Amount(whole: 100, of: .usdc)
        let amountOut = Amount(whole: 105, of: .usdc)
        #expect(Fraction(amountOut - amountIn, over: amountIn) == Fraction(percent: 5))
    }
}
