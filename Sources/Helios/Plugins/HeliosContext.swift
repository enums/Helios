//
//  HeliosContext.swift
//  Helios
//
//  Context structs passed to Task / Timer during construction,
//  so they can access app-level dependencies at init time.
//

import Foundation
import Vapor
import Queues

/// Context provided to `HeliosTask` at construction time.
public struct HeliosTaskContext {
    public let app: HeliosApp
    public let queues: Application.Queues

    public init(app: HeliosApp, queues: Application.Queues) {
        self.app = app
        self.queues = queues
    }
}

/// Context provided to `HeliosTimer` at construction time.
public struct HeliosTimerContext {
    public let app: HeliosApp
    public let queues: Application.Queues

    public init(app: HeliosApp, queues: Application.Queues) {
        self.app = app
        self.queues = queues
    }
}
