// C6 — The rule for two instances that should be one, and the errors, as the design keeps it.
// Projected from docs/fosline-suite-protocols.md C6: "The boundary validates and the inside trusts. ... Inside
// FOSTradingEngine two assets where one was required is then a programmer error, which is what a precondition is for."
// And from the design § 3.1: "A plain add across instances is refused: it traps inside a cycle (C6's rule), and
// `adding(_:)` throws `instanceConflict` at a boundary."

import CryptoAsset
import Foundation
import Testing

@Suite("C6 Boundary rule across instances")
struct C6_BoundaryRuleTests {
    private let left = AssetInstance.stub(address: "quarry-42")
    private let right = AssetInstance.stub(address: "slate-42")

    // "`adding(_:)` throws `instanceConflict` at a boundary"
    @Test func addingAcrossInstancesThrowsInstanceConflict() {
        let a = Amount(baseUnits: 42, of: left)
        let b = Amount(baseUnits: 42, of: right)
        #expect(throws: AmountError.instanceConflict(left, right)) { try a.adding(b) }
    }

    // "Throws ``AmountError/instanceConflict(_:_:)`` when the instances differ" — subtracting too
    @Test func subtractingAcrossInstancesThrowsInstanceConflict() {
        let a = Amount(baseUnits: 42, of: left)
        let b = Amount(baseUnits: 42, of: right)
        #expect(throws: AmountError.instanceConflict(left, right)) { try a.subtracting(b) }
    }

    // "The throwing pair `adding(_:)` and `subtracting(_:)` exists for the boundary itself"
    @Test func addingWithinOneInstanceIsExact() throws {
        let a = Amount(baseUnits: 40, of: left)
        let b = Amount(baseUnits: 2, of: left)
        #expect(try a.adding(b) == Amount(baseUnits: 42, of: left))
        #expect(try a.subtracting(b) == Amount(baseUnits: 38, of: left))
    }

    // "Total: two amounts of different instances are not equal and do not trap"
    @Test func equalityAcrossInstancesIsFalse() {
        #expect(Amount(baseUnits: 42, of: left) != Amount(baseUnits: 42, of: right))
    }

    // "`+` across the two traps (an exit test)"
    @Test func plusAcrossInstancesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: .stub(address: "quarry-42")) + Amount(baseUnits: 1, of: .stub(address: "slate-42"))
        }
    }

    // "`<`, `+`, `-` ... across assets trap, asserted with Swift Testing's exit tests" — minus
    @Test func minusAcrossInstancesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: .stub(address: "quarry-42")) - Amount(baseUnits: 1, of: .stub(address: "slate-42"))
        }
    }

    // "Precondition: both amounts are of one instance" on `<`
    @Test func lessThanAcrossInstancesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Amount(baseUnits: 1, of: .stub(address: "quarry-42")) < Amount(baseUnits: 2, of: .stub(address: "slate-42"))
        }
    }

    // "two instances that should be one" — same address on two chains is two instances
    @Test func sameAddressOnTwoChainsConflicts() {
        let onOne = AssetInstance.stub(chainId: "bedrock:42", address: "quarry-42")
        let onTwo = AssetInstance.stub(chainId: "bedrock:43", address: "quarry-42")
        #expect(throws: AmountError.instanceConflict(onOne, onTwo)) {
            try Amount(baseUnits: 1, of: onOne).adding(Amount(baseUnits: 1, of: onTwo))
        }
    }
}
