// CryptoEquivalencyMap.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct CryptoEquivalencyMap {
    private let map: [String: [any CryptoContract]]

    public func equivalentContracts(to contract: any CryptoContract) -> [any CryptoContract]? {
        // TODO: Probably need to index this as some point
        for list in map.values {
            if list.contains(where: { $0.isSame(as: contract) }) {
                return list
            }
        }

        return nil
    }

    init(map: [String: [any CryptoContract]]) {
        self.map = map
    }
}
