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

/// A timer declaration that pairs runtime metadata with a context-aware timer factory.
public struct HeliosTimerDescriptor {

    /// Runtime metadata (name, kind, criticality, retry policy).
    public let metadata: HeliosRuntimeMetadata

    /// Human-readable timer name for logging / debugging.
    public var name: String { metadata.name }

    /// Factory that receives a `HeliosTimerContext` and returns a configured timer.
    public let makeTimer: (HeliosTimerContext) -> HeliosTimer

    public init(
        metadata: HeliosRuntimeMetadata,
        makeTimer: @escaping (HeliosTimerContext) -> HeliosTimer
    ) {
        self.metadata = metadata
        self.makeTimer = makeTimer
    }

    public init(
        name: String,
        makeTimer: @escaping (HeliosTimerContext) -> HeliosTimer
    ) {
        self.metadata = HeliosRuntimeMetadata(name: name, kind: .timer)
        self.makeTimer = makeTimer
    }
}

// MARK: - Convenience initializer from HeliosTimer type

extension HeliosTimerDescriptor {

    /// Create a descriptor that uses the timer type's context-aware init.
    public init<T: HeliosTimer>(name: String? = nil, timer: T.Type) {
        let resolvedName = name ?? String(describing: T.self)
        self.metadata = HeliosRuntimeMetadata(name: resolvedName, kind: .timer)
        self.makeTimer = { context in T.init(context: context) }
    }

    /// Create a descriptor with full metadata that uses the timer type's context-aware init.
    public init<T: HeliosTimer>(metadata: HeliosRuntimeMetadata, timer: T.Type) {
        self.metadata = metadata
        self.makeTimer = { context in T.init(context: context) }
    }
}
