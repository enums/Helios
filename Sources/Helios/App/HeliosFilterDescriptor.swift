//
//  HeliosFilterDescriptor.swift
//  Helios
//
//  Descriptor for filter extension points. Separates declaration metadata
//  (name) from instance construction (makeFilter).
//

import Foundation
import Vapor

/// A filter declaration that pairs an optional name with a context-aware filter factory.
public struct HeliosFilterDescriptor {

    /// Optional human-readable name for logging / debugging.
    public let name: String?

    /// Factory that receives a `HeliosFilterContext` and returns a configured filter.
    public let makeFilter: (HeliosFilterContext) -> HeliosFilter

    public init(
        name: String? = nil,
        makeFilter: @escaping (HeliosFilterContext) -> HeliosFilter
    ) {
        self.name = name
        self.makeFilter = makeFilter
    }
}

// MARK: - Convenience initializer from HeliosFilter type

extension HeliosFilterDescriptor {

    /// Create a descriptor that uses the filter type's context-aware init.
    public init<F: HeliosFilter>(name: String? = nil, filter: F.Type) {
        self.name = name ?? String(describing: F.self)
        self.makeFilter = { context in F.init(context: context) }
    }
}
