//
//  HeliosTaskDescriptor.swift
//  Helios
//
//  Descriptor for task extension points. Separates declaration metadata
//  (name) from instance construction (makeTask).
//

import Foundation
import Vapor
import Queues

/// A task declaration that pairs runtime metadata with a context-aware task factory.
public struct HeliosTaskDescriptor {

    /// Runtime metadata (name, kind, criticality, retry policy).
    public let metadata: HeliosRuntimeMetadata

    /// Human-readable task name for logging / debugging.
    public var name: String { metadata.name }

    /// Factory that receives a `HeliosTaskContext` and returns a configured task.
    public let makeTask: (HeliosTaskContext) -> HeliosAnyTask

    public init(
        metadata: HeliosRuntimeMetadata,
        makeTask: @escaping (HeliosTaskContext) -> HeliosAnyTask
    ) {
        self.metadata = metadata
        self.makeTask = makeTask
    }

    public init(
        name: String,
        makeTask: @escaping (HeliosTaskContext) -> HeliosAnyTask
    ) {
        self.metadata = HeliosRuntimeMetadata(name: name, kind: .task)
        self.makeTask = makeTask
    }
}

// MARK: - Convenience initializer from HeliosTask type

extension HeliosTaskDescriptor {

    /// Create a descriptor that uses the task type's context-aware init.
    public init<T: HeliosTask>(name: String? = nil, task: T.Type) {
        let resolvedName = name ?? String(describing: T.self)
        self.metadata = HeliosRuntimeMetadata(name: resolvedName, kind: .task)
        self.makeTask = { context in T.init(context: context) }
    }

    /// Create a descriptor with full metadata that uses the task type's context-aware init.
    public init<T: HeliosTask>(metadata: HeliosRuntimeMetadata, task: T.Type) {
        self.metadata = metadata
        self.makeTask = { context in T.init(context: context) }
    }
}
