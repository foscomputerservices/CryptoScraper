// IdentityTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Testing

// An asset is the class of its instances, keyed by its home instance's id (design § 1.5); what a person names, the
// units, and each instance's decimals are its declaration's (§ 2.1). C2's rule of 2026-10-01, "the symbol and the
// exponent", is replaced, so its two tests here went with it.

@Suite("Identity")
struct IdentityTests {
    @Test func anAssetIsItsHomeInstancesId() throws {
        #expect(try Asset(validating: "iso4217:USD") == .usd)
        #expect(try Asset(validating: "eip155:1:eth") == .eth)
        #expect(try Asset(validating: "eip155:10:eth") != .eth)
        #expect(Set<Asset>([.usd, .usdc, .usdt, .btc, .eth]).count == 5)
    }

    @Test func aMalformedIdIsNoAsset() {
        #expect(throws: AssetError.malformedIdentity("USD")) {
            try Asset(validating: "USD")
        }
    }

    @Test(arguments: [31, -1])
    func decimalsOutOfRangeThrow(decimals: Int) throws {
        let symbol = try AssetSymbol(validating: "BTC")
        #expect(throws: AssetError.decimalsOutOfRange(decimals)) {
            try AssetDeclaration.Instance(instance: Fixtures.btc, decimals: decimals, symbol: symbol)
        }
    }

    @Test func theRangeIsZeroThroughThirty() throws {
        let symbol = try AssetSymbol(validating: "BTC")
        #expect(try AssetDeclaration.Instance(instance: Fixtures.btc, decimals: 0, symbol: symbol).decimals == 0)
        #expect(try AssetDeclaration.Instance(instance: Fixtures.btc, decimals: 30, symbol: symbol).decimals == 30)
    }

    @Test func aDeclarationWithNoInstanceThrows() throws {
        #expect(throws: AssetError.noInstances) {
            try AssetDeclaration(asset: .btc, tokenName: "Bitcoin", symbol: AssetSymbol(validating: "BTC"), instances: [])
        }
    }

    @Test func aUnitAboveTheHomesDecimalsThrows() throws {
        let nine = Asset.Unit(name: "nine", exponent: 9)
        let symbol = try AssetSymbol(validating: "BTC")
        let home = try AssetDeclaration.Instance(instance: Fixtures.btc, decimals: 8, symbol: symbol)
        #expect(throws: AssetError.unitOutOfRange(nine)) {
            try AssetDeclaration(asset: .btc, tokenName: "Bitcoin", symbol: symbol, between: [nine], instances: [home])
        }
    }

    @Test func neverWithoutAUnit() throws {
        let usdc = Fixtures.libraryDeclaration(of: .usdc)
        #expect(usdc.wholeUnit.name == "USDC")
        #expect(usdc.wholeUnit.exponent == 6)
        #expect(usdc.baseUnit == nil)
        #expect(usdc.units == [usdc.wholeUnit])
        #expect(usdc.displayUnit == usdc.wholeUnit)
    }

    @Test func theUnitsInOrder() {
        let eth = Fixtures.libraryDeclaration(of: .eth)
        #expect(eth.wholeUnit.exponent == 18)
        #expect(eth.baseUnit?.name == "wei")
        #expect(eth.units.map(\.name) == ["wei", "gwei", "ether"])
        #expect(eth.unit(named: "gwei") == Fixtures.gwei)
        #expect(eth.unit(named: "finney") == nil)
    }

    @Test func theLibrarysDeclarations() {
        let usd = Fixtures.libraryDeclaration(of: .usd)
        #expect(usd.instances.map(\.instance) == [Fixtures.usd])
        #expect(usd.instances.map(\.decimals) == [2])
        #expect(usd.wholeUnit == .init(name: "dollar", exponent: 2, symbol: "$", fractionDigits: 2))
        #expect(usd.baseUnit == .init(name: "cent", exponent: 0, symbol: "¢"))
        #expect(Fixtures.libraryDeclaration(of: .usdc) == Assets.usdCoin)
        #expect(Fixtures.libraryDeclaration(of: .usdc).instances.map(\.decimals) == [6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 6, 6, 6])
        #expect(Fixtures.libraryDeclaration(of: .usdt) == Assets.tether)
        #expect(Fixtures.libraryDeclaration(of: .usdt).instances.map(\.decimals) == [6, 6, 6, 6, 6, 6])
        let btc = Fixtures.libraryDeclaration(of: .btc)
        #expect(btc.instances.map(\.decimals) == [8])
        #expect(btc.baseUnit?.name == "satoshi")
        #expect(btc.wholeUnit.symbol == "₿")
        let eth = Fixtures.libraryDeclaration(of: .eth)
        #expect(eth.instances == [EIP155.Ethereum.eth, EIP155.Optimism.eth, EIP155.Base.eth])
        #expect(eth.instances.map(\.decimals) == [18, 18, 18])
        #expect(eth.wholeUnit.symbol == "Ξ")
        #expect(AssetRegistry.libraryDeclarations.map(\.asset.id) == [
            Asset.usd.id, Asset.btc.id, Asset.eth.id,
            EIP155.BinanceSmartChain.bnb.instance.id, EIP155.Polygon.pol.instance.id, EIP155.Fantom.ftm.instance.id,
            TRON.Tron.trx.instance.id, EIP155.Avalanche.avax.instance.id, EIP155.EthereumClassic.etc.instance.id,
            EIP155.Celo.celo.instance.id, EIP155.Theta.tfuel.instance.id, EIP155.COTI.coti.instance.id,
            SOLANA.Solana.sol.instance.id, XRPL.XRPLedger.xrp.instance.id, STELLAR.Stellar.xlm.instance.id,
            TEZOS.Tezos.xtz.instance.id, ALGORAND.Algorand.algo.instance.id, HEDERA.Hedera.hbar.instance.id,
            NEO.Neo.neo.instance.id, NEO.Neo.gas.instance.id, FIL.Filecoin.fil.instance.id, MVX.MultiversX.egld.instance.id, STACKS.Stacks.stx.instance.id, IOTA.Iota.iota.instance.id, VECHAIN.VeChain.vet.instance.id, VECHAIN.VeChain.vtho.instance.id, ARWEAVE.Arweave.ar.instance.id, MINA.Mina.mina.instance.id, CONFLUX.Conflux.cfx.instance.id, FLOW.Flow.flow.instance.id, BIP122.Litecoin.ltc.instance.id, BIP122.Dogecoin.doge.instance.id, BIP122.BitcoinCash.bch.instance.id, BIP122.Dash.dash.instance.id, BIP122.DigiByte.dgb.instance.id, BIP122.Ravencoin.rvn.instance.id, BIP122.Zcash.zec.instance.id, BIP122.Verge.xvg.instance.id, BIP122.Qtum.qtum.instance.id, BIP122.ECash.xec.instance.id, COSMOS.CosmosHub.atom.instance.id, COSMOS.THORChain.rune.instance.id, COSMOS.Terra.luna.instance.id, COSMOS.FetchAI.fet.instance.id, POLKADOT.Polkadot.dot.instance.id, POLKADOT.Kusama.ksm.instance.id, NEAR.Near.near.instance.id, CIP34.Cardano.ada.instance.id, ICP.InternetComputer.icp.instance.id, ONT.Ontology.ont.instance.id, ONT.Ontology.ong.instance.id, ZIL.Zilliqa.zil.instance.id, CKB.Nervos.ckb.instance.id, SIA.Sia.sc.instance.id, DCR.Decred.dcr.instance.id, POLKADOT.Enjin.enj.instance.id
        ] + Assets.all.map(\.asset.id))
        #expect(Assets.all.map(\.asset).prefix(2) == [.usdt, .usdc])
    }

    /// Step 3 of the identity PR: the coins of CryptoScraper's seven chains are library declarations (brief § 6)
    @Test func theChainsCoinsAreDeclaredAtTheirDecimals() throws {
        let natives = [
            EIP155.BinanceSmartChain.bnb, EIP155.Polygon.pol, EIP155.Fantom.ftm, TRON.Tron.trx, EIP155.Optimism.eth
        ]
        #expect(natives.map(\.decimals) == [18, 18, 18, 6, 18])
        #expect(natives.map(\.symbol.text) == ["BNB", "POL", "FTM", "TRX", "ETH"])
        for native in natives {
            #expect(try AssetRegistry.shared.decimals(of: native.instance) == native.decimals)
        }
        #expect(try AssetRegistry.shared.asset(of: EIP155.Optimism.eth.instance) == .eth)
    }

    @Test func theFiveStaticsAreTheirHomeInstancesIds() {
        #expect(Asset.usd.id == "iso4217:USD")
        #expect(Asset.usdc.id == "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
        #expect(Asset.usdt.id == "eip155:1:0xdac17f958d2ee523a2206206994597c13d831ec7")
        #expect(Asset.btc.id == "bip122:000000000019d6689c085ae165831e93:btc")
        #expect(Asset.eth.id == "eip155:1:eth")
    }
}
