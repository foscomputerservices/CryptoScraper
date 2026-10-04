// Exports.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

@_exported import Numberick

/// The library's `Int128` is Numberick's double-width integer, as it was written in 2023 before the standard library had one.
/// Said here so every toolchain resolves the name the same way for the module and for whoever imports it: Swift 6.2 and 6.3
/// let the standard type win in a test file where 6.4 lets the exported alias win.
public typealias Int128 = NBKDoubleWidthKit.Int128
