//
//  HeliosTimer.swift
//  Helios
//
//  Created by Yuu Zheng on 12/30/22.
//

import Foundation
import Vapor
import Queues

/// Builder that receives a `HeliosTimerContext` and returns a configured timer.
/// **Breaking change from v0:** previously `() -> HeliosTimer`.
public typealias HeliosTimerBuilder = (HeliosTimerContext) -> HeliosTimer

public protocol HeliosTimer: AsyncScheduledJob {

    /// Legacy no-arg constructor. Still required for backward compat default impl.
    init()

    /// Context-aware constructor. Override this to access app-level dependencies at init time.
    init(context: HeliosTimerContext)

    func schedule(queue: Application.Queues)
}

public extension HeliosTimer {

    /// Default: context-aware init falls back to no-arg init.
    /// Existing timers that only implement `init()` continue to work.
    init(context: HeliosTimerContext) {
        self.init()
    }

    /// Context-aware builder. Passes context through to `init(context:)`.
    static var builder: HeliosTimerBuilder {
        return { context in
            Self.init(context: context)
        }
    }
}
