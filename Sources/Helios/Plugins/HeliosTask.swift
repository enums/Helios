//
//  HeliosTask.swift
//  Helios
//
//  Created by Yuu Zheng on 12/30/22.
//

import Foundation
import Vapor
import Queues

public typealias HeliosAnyTask = AnyJob

/// Builder that receives a `HeliosTaskContext` and returns a configured task.
/// **Breaking change from v0:** previously `() -> HeliosAnyTask`.
public typealias HeliosAnyTaskBuilder = (HeliosTaskContext) -> HeliosAnyTask

public protocol HeliosTask: AsyncJob {

    /// Legacy no-arg constructor. Still required for backward compat default impl.
    init()

    /// Context-aware constructor. Override this to access app-level dependencies at init time.
    init(context: HeliosTaskContext)

    func register(queue: Application.Queues)
}

public extension HeliosTask {

    /// Default: context-aware init falls back to no-arg init.
    /// Existing tasks that only implement `init()` continue to work.
    init(context: HeliosTaskContext) {
        self.init()
    }

    /// Context-aware builder. Passes context through to `init(context:)`.
    static var builder: HeliosAnyTaskBuilder {
        return { context in
            Self.init(context: context)
        }
    }

    func register(queue: Application.Queues) {
        queue.add(self)
    }
}
