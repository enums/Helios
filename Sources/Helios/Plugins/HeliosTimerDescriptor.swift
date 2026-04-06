//
//  HeliosTimerDescriptor.swift
//  Helios
//
//  Descriptor for timer extension points. Separates declaration metadata
//  (name) from instance construction (makeTimer).
//

import Foundation
import Vapor
import Queues

/// A timer declaration that pairs a name with a context-aware timer factory.
public struct HeliosTimerDescriptor {

    /// Human-readable timer name for logging / debugging.
    public let name: String

    /// Factory that receives a `HeliosTimerContext` and returns a configured timer.
    public let makeTimer: (HeliosTimerContext) -> HeliosTimer

    public init(
        name: String,
        makeTimer: @escaping (HeliosTimerContext) -> HeliosTimer
    ) {
        self.name = name
        self.makeTimer = makeTimer
    }
}

// MARK: - Convenience initializer from HeliosTimer type

extension HeliosTimerDescriptor {

    /// Create a descriptor that uses the timer type's context-aware init.
    public init<T: HeliosTimer>(name: String? = nil, timer: T.Type) {
        self.name = name ?? String(describing: T.self)
        self.makeTimer = { context in T.init(context: context) }
    }
}
