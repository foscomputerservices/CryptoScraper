// Currency.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// Represents the units of an ``Amount``
///
/// ``Amount`` abstracts all forms of *units of value* allowing
/// for generalized processing of ``Amount``s.
public protocol Currency: CurrencyFormatter, Stubbable, Codable, Hashable {}
