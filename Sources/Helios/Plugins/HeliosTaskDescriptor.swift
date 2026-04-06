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

/// A task declaration that pairs a name with a context-aware task factory.
public struct HeliosTaskDescriptor {

    /// Human-readable task name for logging / debugging.
    public let name: String

    /// Factory that receives a `HeliosTaskContext` and returns a configured task.
    public let makeTask: (HeliosTaskContext) -> HeliosAnyTask

    public init(
        name: String,
        makeTask: @escaping (HeliosTaskContext) -> HeliosAnyTask
    ) {
        self.name = name
        self.makeTask = makeTask
    }
}

// MARK: - Convenience initializer from HeliosTask type

extension HeliosTaskDescriptor {

    /// Create a descriptor that uses the task type's context-aware init.
    public init<T: HeliosTask>(name: String? = nil, task: T.Type) {
        self.name = name ?? String(describing: T.self)
        self.makeTask = { context in T.init(context: context) }
    }
}
